//! Transient presentation only. Provider IDs remain exact decimal strings on web.
#[derive(Clone)]
pub struct GithubCredentialReference {
    pub record_ref: String,
    pub title: String,
    pub username: String,
    pub revision: String,
    pub pending_id: Option<String>,
}
pub struct GithubCredentialReferencePage {
    pub items: Vec<GithubCredentialReference>,
    pub next_after: String,
    pub has_more: bool,
}
#[derive(Clone, Copy)]
pub enum GithubOwnerKindView {
    User,
    Organization,
}
pub struct GithubOwnerView {
    pub id: String,
    pub login: String,
    pub kind: GithubOwnerKindView,
}
#[derive(Clone, Copy)]
pub enum GithubRepositoryVisibilityView {
    Public,
    Private,
    Internal,
}
pub struct GithubRepositorySummaryView {
    pub id: String,
    pub name: String,
    pub visibility: GithubRepositoryVisibilityView,
    pub archived: bool,
    pub default_branch: Option<String>,
}
pub struct GithubRepositoryGroupView {
    pub owner: GithubOwnerView,
    pub repositories: Vec<GithubRepositorySummaryView>,
}
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum GithubCatalogContinuationView {
    More,
    EndOfAccessScope,
    LimitReached,
}
pub struct GithubRepositoryPageView {
    pub principal: GithubOwnerView,
    pub groups: Vec<GithubRepositoryGroupView>,
    pub observed_at_ms: String,
    pub continuation: GithubCatalogContinuationView,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GithubCatalogError {
    InvalidInput,
    AuthorizationRequired,
    CredentialChanged,
    Busy,
    Cancelled,
    Timeout,
    Unavailable,
    ProviderFailed,
    InvalidResponse,
}

impl std::fmt::Display for GithubCatalogError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}
impl std::error::Error for GithubCatalogError {}

impl From<nddev_device_sync_domain::modules::ModuleError> for GithubCatalogError {
    fn from(error: nddev_device_sync_domain::modules::ModuleError) -> Self {
        use nddev_device_sync_domain::modules::ModuleError as E;
        match error {
            E::InvalidInput => Self::InvalidInput,
            E::Busy => Self::Busy,
            E::Cancelled => Self::Cancelled,
            E::Timeout => Self::Timeout,
            E::InvalidResponse | E::InvalidContract => Self::InvalidResponse,
            E::ProviderFailed => Self::ProviderFailed,
            E::UnsupportedPlatform | E::Unavailable => Self::Unavailable,
        }
    }
}
impl From<nddev_device_sync_accounts::view::ClientError> for GithubCatalogError {
    fn from(error: nddev_device_sync_accounts::view::ClientError) -> Self {
        use nddev_device_sync_accounts::view::ClientError as E;
        match error {
            E::Busy => Self::Busy,
            E::Cancelled => Self::Cancelled,
            E::Timeout => Self::Timeout,
            E::CredentialStore | E::Transport | E::TelemetryUnavailable => Self::Unavailable,
            E::InvalidResponse => Self::InvalidResponse,
            _ => Self::AuthorizationRequired,
        }
    }
}
impl From<nddev_device_sync_vault::view::VaultError> for GithubCatalogError {
    fn from(error: nddev_device_sync_vault::view::VaultError) -> Self {
        use nddev_device_sync_vault::view::VaultError as E;
        match error {
            E::Busy => Self::Busy,
            E::Cancelled => Self::Cancelled,
            E::Invalid => Self::InvalidResponse,
            E::SelectionChanged => Self::CredentialChanged,
            E::Locked | E::Authentication | E::RegistrationRequired => Self::AuthorizationRequired,
            E::Unavailable | E::StorageFull | E::CapacityExhausted => Self::Unavailable,
        }
    }
}

pub(crate) fn project_page(
    page: nddev_device_sync_domain::repositories::catalog::RepositoryPage,
) -> (
    GithubRepositoryPageView,
    Option<nddev_device_sync_domain::repositories::catalog::CatalogCursor>,
) {
    use nddev_device_sync_domain::repositories::catalog as c;
    fn owner(value: c::GithubOwner) -> GithubOwnerView {
        GithubOwnerView {
            id: value.id.value().to_string(),
            login: value.login,
            kind: match value.kind {
                c::GithubOwnerKind::User => GithubOwnerKindView::User,
                c::GithubOwnerKind::Organization => GithubOwnerKindView::Organization,
            },
        }
    }
    let (continuation, cursor) = match page.continuation {
        c::CatalogContinuation::More(cursor) => (GithubCatalogContinuationView::More, Some(cursor)),
        c::CatalogContinuation::EndOfAccessScope => {
            (GithubCatalogContinuationView::EndOfAccessScope, None)
        }
        c::CatalogContinuation::LimitReached => (GithubCatalogContinuationView::LimitReached, None),
    };
    let groups = page
        .groups
        .into_iter()
        .map(|group| GithubRepositoryGroupView {
            owner: owner(group.owner),
            repositories: group
                .repositories
                .into_iter()
                .map(|repository| GithubRepositorySummaryView {
                    id: repository.id.value().to_string(),
                    name: repository.name,
                    visibility: match repository.visibility {
                        c::RepositoryVisibility::Public => GithubRepositoryVisibilityView::Public,
                        c::RepositoryVisibility::Private => GithubRepositoryVisibilityView::Private,
                        c::RepositoryVisibility::Internal => {
                            GithubRepositoryVisibilityView::Internal
                        }
                    },
                    archived: repository.archived,
                    default_branch: repository.default_branch,
                })
                .collect(),
        })
        .collect();
    (
        GithubRepositoryPageView {
            principal: owner(page.principal),
            groups,
            observed_at_ms: page.observed_at_ms.to_string(),
            continuation,
        },
        cursor,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use nddev_device_sync_domain::repositories::catalog as c;
    #[test]
    fn provider_ids_above_javascript_integer_precision_stay_decimal_strings() {
        let principal = c::GithubOwner {
            id: c::GithubAccountId::new(9_007_199_254_740_993).unwrap(),
            kind: c::GithubOwnerKind::User,
            login: "fixture".into(),
        };
        let selection = c::CredentialSelection::new("record".into(), 7, None).unwrap();
        let request = c::CatalogPageRequest::new(selection, None).unwrap();
        let page = c::ProviderRepositoryPage {
            principal: principal.clone(),
            repositories: vec![c::RepositorySummary {
                id: c::RepositoryId::new(u64::MAX).unwrap(),
                owner: principal,
                name: "fixture".into(),
                visibility: c::RepositoryVisibility::Private,
                archived: false,
                default_branch: None,
            }],
            observed_at_ms: 100,
            has_more: false,
        }
        .into_page(&request)
        .unwrap();
        let (view, cursor) = project_page(page);
        assert_eq!(view.principal.id, "9007199254740993");
        assert_eq!(view.groups[0].owner.id, "9007199254740993");
        assert_eq!(view.groups[0].repositories[0].id, "18446744073709551615");
        assert!(cursor.is_none());
        assert!(view.continuation == GithubCatalogContinuationView::EndOfAccessScope);
    }
}
