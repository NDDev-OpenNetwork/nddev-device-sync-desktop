use flutter_rust_bridge::frb;
use nddev_device_sync_accounts::{
    IdentityClient,
    view::{ClientError, View},
};
use nddev_device_sync_vault::{
    VaultClient,
    view::{PairingPeer, RecordView, StatePage, VaultError, VaultView},
};
use std::{sync::Arc, time::Instant};
use tracing::Instrument;
use zeroize::Zeroizing;

#[frb(opaque)]
pub struct NdsClient {
    inner: Arc<IdentityClient>,
    vault: tokio::sync::Mutex<Option<Arc<VaultClient>>>,
}

impl NdsClient {
    pub fn new(endpoint: String) -> Result<Self, ClientError> {
        Ok(Self {
            inner: Arc::new(IdentityClient::new(&endpoint)?),
            vault: tokio::sync::Mutex::new(None),
        })
    }
    pub async fn refresh(&self) -> Result<View, ClientError> {
        self.inner.refresh().await
    }
    pub async fn request_email(&self, email: String, locale: String) -> Result<View, ClientError> {
        self.inner.request_email(email, &locale).await
    }
    pub async fn verify_email(&self, code: String) -> Result<View, ClientError> {
        self.inner.verify_email(code).await
    }
    pub async fn start_github(&self, locale: String) -> Result<View, ClientError> {
        self.inner.start_github(&locale).await
    }
    pub async fn poll_github(&self) -> Result<View, ClientError> {
        self.inner.poll_github().await
    }
    pub async fn logout(&self) -> Result<View, ClientError> {
        let view = self.inner.logout().await?;
        self.vault.lock().await.take();
        Ok(view)
    }
    pub async fn refresh_devices(&self) -> Result<View, ClientError> {
        self.inner.refresh_devices().await
    }
    pub async fn enroll_device(&self, name: String) -> Result<View, ClientError> {
        self.inner.enroll_device(name).await
    }
    pub async fn revoke_device(&self, id: String) -> Result<View, ClientError> {
        self.inner.revoke_device(id).await
    }
    async fn vault(&self) -> Result<Arc<VaultClient>, VaultError> {
        let mut slot = self.vault.lock().await;
        if let Some(vault) = &*slot {
            return Ok(vault.clone());
        }
        let vault = Arc::new(VaultClient::new(self.inner.clone(), data_directory()?).await?);
        *slot = Some(vault.clone());
        Ok(vault)
    }
    pub async fn vault_refresh(&self) -> Result<VaultView, VaultError> {
        observe("vault.refresh", async {
            self.vault().await?.refresh().await
        })
        .await
    }
    pub async fn vault_create(&self) -> Result<VaultView, VaultError> {
        observe("vault.create", async { self.vault().await?.create().await }).await
    }
    pub async fn vault_sync(&self) -> Result<VaultView, VaultError> {
        observe("vault.sync", async {
            self.vault().await?.synchronize().await
        })
        .await
    }
    pub async fn vault_records(&self) -> Result<Vec<RecordView>, VaultError> {
        observe("vault.records", async {
            self.vault().await?.records().await
        })
        .await
    }
    pub async fn vault_save(
        &self,
        id: Option<String>,
        title: String,
        username: String,
        secret: String,
    ) -> Result<String, VaultError> {
        observe("vault.record.save", async {
            self.vault()
                .await?
                .save_record(id, title, username, Zeroizing::new(secret))
                .await
        })
        .await
    }
    pub async fn vault_pairing_start(&self) -> Result<String, VaultError> {
        observe("vault.pairing.start", async {
            self.vault().await?.start_pairing()
        })
        .await
    }
    pub async fn vault_pairing_grant(&self, code: String) -> Result<String, VaultError> {
        observe("vault.pairing.grant", async {
            self.vault().await?.grant_pairing(code).await
        })
        .await
    }
    pub async fn vault_pairing_preview(&self, code: String) -> Result<PairingPeer, VaultError> {
        observe("vault.pairing.preview", async {
            self.vault().await?.preview_pairing(code).await
        })
        .await
    }
    pub async fn vault_pairing_import(&self, code: String) -> Result<VaultView, VaultError> {
        observe("vault.pairing.import", async {
            self.vault().await?.import_pairing(code).await
        })
        .await
    }
    pub async fn sync_states(&self, after: String) -> Result<StatePage, VaultError> {
        observe("sync.states.read", async {
            self.vault().await?.states(after).await
        })
        .await
    }
    pub async fn publish_device_state(&self) -> Result<VaultView, VaultError> {
        self.publish_state_inner(Vec::new()).await
    }
    pub async fn publish_local_state(
        &self,
        agent: &super::modules::LocalAgent,
    ) -> Result<VaultView, VaultError> {
        self.publish_state_inner(agent.modules().map_err(|_| VaultError::Unavailable)?)
            .await
    }
    async fn publish_state_inner(
        &self,
        modules: Vec<nddev_device_sync_agent::view::ModuleState>,
    ) -> Result<VaultView, VaultError> {
        use nddev_device_sync_domain::state::{Reachability, Snapshot, State};
        observe("sync.states.publish", async {
            let vault = self.vault().await?;
            self.inner
                .refresh_devices()
                .await
                .map_err(|_| VaultError::Unavailable)?;
            let view = self.inner.view();
            let device = view
                .devices
                .into_iter()
                .find(|value| value.is_current && !value.revoked)
                .ok_or(VaultError::Locked)?;
            let observed_at_ms = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map_err(|_| VaultError::Unavailable)?
                .as_millis()
                .try_into()
                .map_err(|_| VaultError::Invalid)?;
            let capture = |data| Snapshot {
                schema_version: 1,
                observed_at_ms,
                data,
            };
            let expires = time::OffsetDateTime::parse(
                &view.expires_at,
                &time::format_description::well_known::Rfc3339,
            )
            .map_err(|_| VaultError::Invalid)?
            .unix_timestamp();
            let millis = |seconds: i64| {
                u64::try_from(seconds)
                    .ok()
                    .and_then(|value| value.checked_mul(1000))
                    .ok_or(VaultError::Invalid)
            };
            let mut values = vec![
                capture(State::Device {
                    display_name: device.display_name,
                    platform: device.platform,
                    client_version: env!("CARGO_PKG_VERSION").into(),
                }),
                capture(State::Account {
                    auth_method: view.auth_method,
                    checked_at_ms: millis(view.session_checked_at)?,
                    expires_at_ms: millis(expires)?,
                }),
            ];
            for module in modules {
                let reachability = match module.reachability {
                    nddev_device_sync_agent::view::Reachability::NotChecked => {
                        Reachability::NotChecked
                    }
                    nddev_device_sync_agent::view::Reachability::Reachable => {
                        Reachability::Reachable
                    }
                    nddev_device_sync_agent::view::Reachability::Unavailable => {
                        Reachability::Unavailable
                    }
                    nddev_device_sync_agent::view::Reachability::Failed => Reachability::Failed,
                };
                values.push(capture(State::Module {
                    module_id: module.id,
                    version: module.version,
                    configured: module.configured,
                    reachability,
                    checked_at_ms: module.observed_at_ms,
                    error_class: module.error.map(|error| error.to_string()),
                }));
            }
            vault.publish_states(values).await
        })
        .await
    }
    #[frb(sync)]
    pub fn snapshot(&self) -> View {
        self.inner.view()
    }
    #[frb(sync)]
    pub fn cancel(&self) {
        self.inner.cancel_sign_in();
    }
}

async fn observe<T>(
    event: &'static str,
    work: impl std::future::Future<Output = Result<T, VaultError>>,
) -> Result<T, VaultError> {
    let span = nddev_device_sync_telemetry::operation_span("vault", "process")
        .map_err(|_| VaultError::Unavailable)?;
    async {
        let start=Instant::now();let result=work.await;
        match &result {
            Ok(_)=>tracing::event!(target:"nds_native",tracing::Level::INFO,{event.name=event,module="vault",duration_ms=start.elapsed().as_millis() as u64,outcome="ok"}),
            Err(error)=>tracing::event!(target:"nds_native",tracing::Level::WARN,{event.name=event,module="vault",duration_ms=start.elapsed().as_millis() as u64,error.type=%error,outcome="error"}),
        }
        result
    }.instrument(span).await
}
fn data_directory() -> Result<std::path::PathBuf, VaultError> {
    #[cfg(target_os = "android")]
    {
        return nddev_device_sync_accounts::android::private_data_directory()
            .map_err(|_| VaultError::Unavailable);
    }
    #[cfg(not(target_os = "android"))]
    {
        #[cfg(target_os = "windows")]
        let root = std::env::var_os("LOCALAPPDATA").map(std::path::PathBuf::from);
        #[cfg(any(target_os = "ios", target_os = "macos"))]
        let root = std::env::var_os("HOME")
            .map(|home| std::path::PathBuf::from(home).join("Library/Application Support"));
        #[cfg(target_os = "linux")]
        let root = std::env::var_os("XDG_STATE_HOME")
            .map(std::path::PathBuf::from)
            .or_else(|| {
                std::env::var_os("HOME")
                    .map(|home| std::path::PathBuf::from(home).join(".local/state"))
            });
        let root = root.ok_or(VaultError::Unavailable)?;
        if !root.is_absolute() {
            return Err(VaultError::Invalid);
        }
        Ok(root.join("nddev-device-sync"))
    }
}
