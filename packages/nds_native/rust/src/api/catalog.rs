//! NdsClient owns one transient catalog flight and cursor. No LocalAgent dependency.
use super::{catalog_types::*, identity::NdsClient};
use flutter_rust_bridge::frb;
use nddev_device_sync_accounts::{IdentityClient, LocalUseFence, runtime};
use nddev_device_sync_application::repositories::catalog::{self, ReadGithubCatalogPage};
use nddev_device_sync_domain::repositories::catalog::{
    CatalogCursor, CatalogPageRequest, CredentialSelection, ProviderRepositoryPage,
};
use nddev_device_sync_vault::VaultClient;
use std::{
    sync::{Arc, Mutex},
    time::Duration,
};
use tokio_util::sync::CancellationToken;

#[frb(ignore)]
pub(crate) struct CatalogState {
    selection: Option<CredentialSelection>,
    cursor: Option<CatalogCursor>,
    fence: Option<Arc<LocalUseFence>>,
    lifetime: Arc<CancellationToken>,
    flight: Option<Arc<CancellationToken>>,
}
impl Default for CatalogState {
    #[frb(ignore)]
    fn default() -> Self {
        Self {
            selection: None,
            cursor: None,
            fence: None,
            lifetime: Arc::new(CancellationToken::new()),
            flight: None,
        }
    }
}
impl CatalogState {
    pub(crate) fn invalidate(&mut self, clear_selection: bool) {
        self.lifetime.cancel();
        if let Some(flight) = &self.flight {
            flight.cancel();
        }
        self.lifetime = Arc::new(CancellationToken::new());
        self.cursor = None;
        self.fence = None;
        if clear_selection {
            self.selection = None;
        }
        // The admitted future retains the flight until it has actually ended.
    }
}
struct Flight<'a> {
    state: &'a Mutex<CatalogState>,
    cancellation: Arc<CancellationToken>,
    lifetime: Arc<CancellationToken>,
}
impl Flight<'_> {
    fn check(&self) -> Result<(), GithubCatalogError> {
        if self.cancellation.is_cancelled() || self.lifetime.is_cancelled() {
            Err(GithubCatalogError::Cancelled)
        } else {
            Ok(())
        }
    }
}
impl<'a> Flight<'a> {
    fn begin(owner: &'a Mutex<CatalogState>) -> Result<Self, GithubCatalogError> {
        let mut state = owner.lock().unwrap_or_else(|e| e.into_inner());
        if state.flight.is_some() {
            return Err(GithubCatalogError::Busy);
        }
        let cancellation = Arc::new(CancellationToken::new());
        state.flight = Some(cancellation.clone());
        Ok(Self {
            state: owner,
            cancellation,
            lifetime: state.lifetime.clone(),
        })
    }
}
impl Drop for Flight<'_> {
    fn drop(&mut self) {
        let mut state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        if state
            .flight
            .as_ref()
            .is_some_and(|current| Arc::ptr_eq(current, &self.cancellation))
        {
            state.flight = None;
        }
    }
}

/// This exact guard is the callback required inside GDS before EACH provider GET
/// and final return, within its overall deadline; an outer recheck is insufficient.
#[derive(Clone)]
struct CatalogUseGuard {
    identity: Arc<IdentityClient>,
    vault: Arc<VaultClient>,
    selection: CredentialSelection,
    fence: Arc<LocalUseFence>,
    cancellation: Arc<CancellationToken>,
    lifetime: Arc<CancellationToken>,
}
impl CatalogUseGuard {
    fn check(&self) -> Result<(), GithubCatalogError> {
        if self.cancellation.is_cancelled() || self.lifetime.is_cancelled() {
            Err(GithubCatalogError::Cancelled)
        } else {
            Ok(())
        }
    }
    async fn validate(&self) -> Result<(), GithubCatalogError> {
        self.check()?;
        self.identity.validate_local_use(&self.fence).await?;
        self.check()?;
        self.vault.ensure_record_current(&self.selection).await?;
        self.check()?;
        self.identity.validate_local_use(&self.fence).await?;
        self.check()
    }
}

#[cfg(not(target_arch = "wasm32"))]
type GuardFuture = std::pin::Pin<
    Box<
        dyn std::future::Future<Output = Result<(), nddev_device_sync_domain::modules::ModuleError>>
            + Send,
    >,
>;
#[cfg(target_arch = "wasm32")]
type GuardFuture = std::pin::Pin<
    Box<
        dyn std::future::Future<Output = Result<(), nddev_device_sync_domain::modules::ModuleError>>,
    >,
>;

// Explicit native Send/browser-local future fits FRB's existing executors.
// This box owns no grant or secret; typed refusal is transient to this read.
fn revalidation(
    guard: CatalogUseGuard,
    errors: Arc<Mutex<Option<GithubCatalogError>>>,
) -> GuardFuture {
    Box::pin(async move {
        match guard.validate().await {
            Ok(()) => Ok(()),
            Err(error) => {
                *errors.lock().unwrap_or_else(|e| e.into_inner()) = Some(error);
                use nddev_device_sync_domain::modules::ModuleError as E;
                Err(match error {
                    GithubCatalogError::Cancelled => E::Cancelled,
                    GithubCatalogError::Busy => E::Busy,
                    GithubCatalogError::Timeout => E::Timeout,
                    GithubCatalogError::InvalidInput => E::InvalidInput,
                    GithubCatalogError::InvalidResponse => E::InvalidResponse,
                    GithubCatalogError::ProviderFailed => E::ProviderFailed,
                    GithubCatalogError::AuthorizationRequired
                    | GithubCatalogError::CredentialChanged
                    | GithubCatalogError::Unavailable => E::Unavailable,
                })
            }
        }
    })
}
struct CatalogPort {
    guard: CatalogUseGuard,
}
impl ReadGithubCatalogPage for CatalogPort {
    type Error = GithubCatalogError;
    type Cancellation = CancellationToken;
    async fn read_page(
        &self,
        request: &CatalogPageRequest,
        cancellation: &CancellationToken,
    ) -> Result<ProviderRepositoryPage, GithubCatalogError> {
        self.guard.check()?;
        self.guard
            .identity
            .validate_local_use(&self.guard.fence)
            .await?;
        self.guard.check()?;
        // Conditional Vault resolution owns exact selection validation.
        let credential = self
            .guard
            .vault
            .native_secret_at(request.selection())
            .await?;
        self.guard.check()?;
        self.guard
            .identity
            .validate_local_use(&self.guard.fence)
            .await?;
        self.guard.check()?;
        let guard_error = Arc::new(Mutex::new(None));
        let callback_error = guard_error.clone();
        let callback_guard = self.guard.clone();
        let result = nddev_device_sync_gds::github::read_user_and_page(
            credential.as_str(),
            request,
            cancellation,
            move || revalidation(callback_guard.clone(), callback_error.clone()),
        )
        .await;
        result.map_err(|error| {
            guard_error
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .to_owned()
                .unwrap_or_else(|| error.into())
        })
    }
}

fn caller_error(error: &GithubCatalogError) -> (String, &'static str, bool) {
    use GithubCatalogError as E;
    let (class, outcome, failure) = match error {
        E::InvalidInput => ("invalid_input", "rejected", false),
        E::AuthorizationRequired => ("credential_revalidation_required", "rejected", false),
        E::CredentialChanged => ("vault_selection_changed", "rejected", false),
        E::Busy => ("operation_busy", "rejected", false),
        E::Cancelled => ("operation_cancelled", "stopped", false),
        E::Timeout => ("operation_timeout", "error", true),
        E::Unavailable => ("provider_unavailable", "error", true),
        E::ProviderFailed => ("provider_failed", "error", true),
        E::InvalidResponse => ("invalid_response", "error", true),
    };
    (class.into(), outcome, failure)
}

impl NdsClient {
    fn catalog_flight(&self) -> Result<Flight<'_>, GithubCatalogError> {
        if !self.catalog_active() {
            return Err(GithubCatalogError::Cancelled);
        }
        Flight::begin(&self.catalog)
    }
    #[frb(ignore)]
    pub(crate) fn invalidate_catalog(&self) {
        self.catalog
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .invalidate(true);
    }
    #[frb(sync)]
    pub fn cancel_github_catalog(&self) {
        self.catalog
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .invalidate(false);
    }
    #[frb(sync)]
    pub fn select_github_credential(
        &self,
        record_ref: String,
        revision: String,
        pending_id: Option<String>,
    ) -> Result<(), GithubCatalogError> {
        let parsed = revision
            .parse::<u64>()
            .map_err(|_| GithubCatalogError::InvalidInput)?;
        if parsed.to_string() != revision {
            return Err(GithubCatalogError::InvalidInput);
        }
        let selection = CredentialSelection::new(record_ref, parsed, pending_id)?;
        let mut state = self.catalog.lock().unwrap_or_else(|e| e.into_inner());
        state.invalidate(true);
        state.selection = Some(selection);
        Ok(())
    }
    pub async fn github_catalog_credentials(
        &self,
        after: String,
    ) -> Result<GithubCredentialReferencePage, GithubCatalogError> {
        super::identity::observe_operation("gds", "gds.catalog.credentials.read", async {
        let flight = self.catalog_flight()?;
        let result = runtime::timeout(Duration::from_secs(10), async {
            tokio::select! { biased;
                _ = flight.cancellation.cancelled() => Err(GithubCatalogError::Cancelled),
                _ = flight.lifetime.cancelled() => Err(GithubCatalogError::Cancelled),
                result = async {
                    let fence = self.catalog_identity().local_use_fence().await?;
                    flight.check()?;
                    let page = self.vault().await?.records(after).await?;
                    self.catalog_identity().validate_local_use(&fence).await?;
                    flight.check()?;
                    Ok(GithubCredentialReferencePage {
                        items: page.items.into_iter().filter(|r| !r.deleted && !r.conflicted).map(|r| GithubCredentialReference {
                            record_ref: r.id, title: r.title, username: r.username,
                            revision: r.revision.to_string(), pending_id: r.pending_id,
                        }).collect(), next_after: page.next_after, has_more: page.has_more,
                    })
                } => result,
            }
        }).await.map_err(|_| GithubCatalogError::Timeout)?;
        flight.check()?;
        result
        }, GithubCatalogError::Unavailable, caller_error).await
    }
    pub async fn github_repository_page(
        &self,
        next_page: bool,
    ) -> Result<GithubRepositoryPageView, GithubCatalogError> {
        super::identity::observe_operation("gds", "gds.catalog.page.read", async {
        let flight = self.catalog_flight()?;
        let (selection, after, prior_fence) = {
            let mut state = self.catalog.lock().unwrap_or_else(|e| e.into_inner());
            let selection = state
                .selection
                .clone()
                .ok_or(GithubCatalogError::InvalidInput)?;
            if next_page {
                (
                    selection,
                    Some(
                        state
                            .cursor
                            .clone()
                            .ok_or(GithubCatalogError::InvalidInput)?,
                    ),
                    Some(
                        state
                            .fence
                            .clone()
                            .ok_or(GithubCatalogError::InvalidInput)?,
                    ),
                )
            } else {
                state.cursor = None;
                state.fence = None;
                (selection, None, None)
            }
        };
        let result = runtime::timeout(Duration::from_secs(10), async {
            tokio::select! { biased;
                _ = flight.cancellation.cancelled() => Err(GithubCatalogError::Cancelled),
                _ = flight.lifetime.cancelled() => Err(GithubCatalogError::Cancelled),
                result = async {
                    let fence = match prior_fence { Some(fence) => fence, None => Arc::new(self.catalog_identity().local_use_fence().await?) };
                    flight.check()?;
                    let vault = self.vault().await?;
                    let port = CatalogPort { guard: CatalogUseGuard { identity: self.catalog_identity().clone(), vault: vault.clone(), selection: selection.clone(), fence: fence.clone(), cancellation: flight.cancellation.clone(), lifetime: flight.lifetime.clone() } };
                    let page = catalog::repository_page(&port, selection.clone(), after.as_ref(), flight.cancellation.as_ref()).await?;
                    port.guard.validate().await?;
                    let (view, cursor) = project_page(page);
                    let mut state = self.catalog.lock().unwrap_or_else(|e| e.into_inner());
                    flight.check()?;
                    if state.selection.as_ref() != Some(&selection) || !Arc::ptr_eq(&state.lifetime, &flight.lifetime) {
                        return Err(GithubCatalogError::CredentialChanged);
                    }
                    state.cursor = cursor; state.fence = Some(fence);
                    Ok(view)
                } => result,
            }
        }).await.map_err(|_| GithubCatalogError::Timeout)?;
        flight.check()?;
        result
        }, GithubCatalogError::Unavailable, caller_error).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn immediate<T>(future: impl std::future::Future<Output = T>) -> T {
        use std::task::{Context, Poll, Waker};
        let mut future = std::pin::pin!(future);
        match future
            .as_mut()
            .poll(&mut Context::from_waker(Waker::noop()))
        {
            Poll::Ready(result) => result,
            Poll::Pending => panic!("continuation preflight must refuse before any I/O"),
        }
    }
    #[test]
    fn session_boundary_and_another_client_refuse_the_previous_continuation_before_io() {
        use nddev_device_sync_domain::repositories::catalog as c;
        // Pure cursor input, not an authenticated/provider success receipt.
        let selection = CredentialSelection::new("record".into(), 7, None).unwrap();
        let request = CatalogPageRequest::new(selection, None).unwrap();
        let page = ProviderRepositoryPage {
            principal: c::GithubOwner {
                id: c::GithubAccountId::new(1).unwrap(),
                kind: c::GithubOwnerKind::User,
                login: "fixture".into(),
            },
            repositories: vec![],
            observed_at_ms: 100,
            has_more: true,
        }
        .into_page(&request)
        .unwrap();
        let c::CatalogContinuation::More(cursor) = page.continuation else {
            panic!("cursor required")
        };
        let first = NdsClient::new("https://catalog-fixture.invalid".into()).unwrap();
        first
            .select_github_credential("record".into(), "7".into(), None)
            .unwrap();
        first.catalog.lock().unwrap().cursor = Some(cursor);
        first.invalidate_catalog(); // The actual session-reset callers use this boundary.
        assert!(first.catalog.lock().unwrap().cursor.is_none());
        first
            .select_github_credential("record".into(), "7".into(), None)
            .unwrap();
        assert!(matches!(
            immediate(first.github_repository_page(true)),
            Err(GithubCatalogError::InvalidInput)
        ));
        let second = NdsClient::new("https://catalog-fixture.invalid".into()).unwrap();
        second
            .select_github_credential("record".into(), "7".into(), None)
            .unwrap();
        assert!(matches!(
            immediate(second.github_repository_page(true)),
            Err(GithubCatalogError::InvalidInput)
        ));
    }
    #[test]
    fn cancellation_keeps_admission_until_the_old_future_ends() {
        let state = Mutex::new(CatalogState::default());
        let first = Flight::begin(&state).unwrap();
        assert!(matches!(
            Flight::begin(&state),
            Err(GithubCatalogError::Busy)
        ));
        state.lock().unwrap().invalidate(true);
        assert_eq!(first.check(), Err(GithubCatalogError::Cancelled));
        assert!(matches!(
            Flight::begin(&state),
            Err(GithubCatalogError::Busy)
        ));
        drop(first);
        let second = Flight::begin(&state).unwrap();
        assert_eq!(second.check(), Ok(()));
    }
    #[test]
    fn replacing_selection_revokes_the_previous_lifetime() {
        let state = Mutex::new(CatalogState::default());
        let first = Flight::begin(&state).unwrap();
        {
            let mut current = state.lock().unwrap();
            current.invalidate(true);
            current.selection = Some(
                CredentialSelection::new("record".into(), 7, Some("new-operation".into())).unwrap(),
            );
        }
        assert_eq!(first.check(), Err(GithubCatalogError::Cancelled));
        drop(first);
        assert_eq!(Flight::begin(&state).unwrap().check(), Ok(()));
    }
}
