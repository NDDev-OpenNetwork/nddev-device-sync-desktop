use flutter_rust_bridge::frb;
use nddev_device_sync_accounts::{
    IdentityClient,
    view::{ClientError, View},
};
use nddev_device_sync_vault::{
    VaultClient,
    view::{RecordView, StatePage, VaultError, VaultView},
};
use std::{
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};
use tracing::Instrument;
use zeroize::Zeroizing;

#[frb(opaque)]
pub struct NdsClient {
    inner: Arc<IdentityClient>,
    vault: tokio::sync::Mutex<Option<Arc<VaultClient>>>,
    replica: Mutex<Option<Replica>>,
    foreground: AtomicBool,
}

struct Replica {
    active: tokio::sync::watch::Sender<bool>,
    task: tokio::task::JoinHandle<()>,
}
impl Drop for Replica {
    fn drop(&mut self) {
        self.task.abort();
    }
}

impl NdsClient {
    pub fn new(endpoint: String) -> Result<Self, ClientError> {
        Ok(Self {
            inner: Arc::new(IdentityClient::new(&endpoint)?),
            vault: tokio::sync::Mutex::new(None),
            replica: Mutex::default(),
            foreground: AtomicBool::new(true),
        })
    }
    pub async fn refresh(&self) -> Result<View, ClientError> {
        self.stop_replica().await;
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
    pub async fn start_passkey(
        &self,
        registration: bool,
        locale: String,
    ) -> Result<View, ClientError> {
        self.inner.start_passkey(registration, &locale).await
    }
    pub async fn poll_passkey(&self) -> Result<View, ClientError> {
        self.inner.poll_passkey().await
    }
    pub async fn poll_github(&self) -> Result<View, ClientError> {
        self.inner.poll_github().await
    }
    pub async fn logout(&self) -> Result<View, ClientError> {
        self.stop_replica().await;
        let view = self.inner.logout().await?;
        self.vault.lock().await.take();
        Ok(view)
    }
    pub async fn refresh_devices(&self) -> Result<View, ClientError> {
        self.inner.refresh_devices().await
    }
    pub async fn prepare_device(&self, name: String) -> Result<View, ClientError> {
        self.stop_replica().await;
        let view = self.inner.prepare_device(name).await?;
        self.start_replica()
            .await
            .map_err(|_| ClientError::Transport)?;
        Ok(view)
    }
    pub async fn revoke_device(&self, id: String) -> Result<View, ClientError> {
        self.stop_replica().await;
        self.inner.revoke_device(id).await
    }
    #[frb(sync)]
    pub fn set_foreground(&self, active: bool) {
        self.foreground.store(active, Ordering::Relaxed);
        if let Some(replica) = &*self.replica.lock().unwrap_or_else(|e| e.into_inner()) {
            replica.active.send_replace(active);
        }
    }
    async fn stop_replica(&self) {
        let replica = self
            .replica
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .take();
        if let Some(mut replica) = replica {
            replica.task.abort();
            let _ = (&mut replica.task).await;
        }
    }
    async fn start_replica(&self) -> Result<(), VaultError> {
        let vault = self.vault().await?;
        let weak = Arc::downgrade(&vault);
        let (active, mut enabled) =
            tokio::sync::watch::channel(self.foreground.load(Ordering::Relaxed));
        let identity = self.inner.clone();
        let mut slot = self.replica.lock().unwrap_or_else(|e| e.into_inner());
        if slot.is_some() {
            return Ok(());
        }
        let task = tokio::spawn(async move {
            let mut delay = Duration::ZERO;
            let mut failures = 0u32;
            let mut published = false;
            loop {
                if !*enabled.borrow() {
                    if enabled.changed().await.is_err() {
                        break;
                    }
                    delay = Duration::ZERO;
                    continue;
                }
                tokio::select! {
                    changed = enabled.changed() => { if changed.is_err() { break; } delay = Duration::ZERO; continue; }
                    _ = tokio::time::sleep(delay) => {}
                }
                let Some(vault) = weak.upgrade() else {
                    break;
                };
                let result = tokio::select! {
                    changed = enabled.changed() => { if changed.is_err() { break; } delay = Duration::ZERO; continue; }
                    result = observe("sync.replica.batch", async {
                        let view = vault.synchronize().await?;
                        if !published && !view.catching_up {
                            let view = vault.publish_states(device_observations(&identity)?).await?;
                            published = true;
                            return Ok(view);
                        }
                        Ok(view)
                    }) => result
                };
                delay = match result {
                    Ok(view) => {
                        failures = 0;
                        if view.catching_up {
                            Duration::from_millis(200)
                        } else {
                            Duration::from_secs(15)
                        }
                    }
                    Err(VaultError::Locked) => break,
                    Err(_) => {
                        failures = failures.saturating_add(1);
                        Duration::from_secs(1u64 << failures.min(5))
                    }
                };
            }
        });
        *slot = Some(Replica { active, task });
        Ok(())
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
    pub async fn vault_snapshot(&self) -> Result<VaultView, VaultError> {
        Ok(self.vault().await?.snapshot())
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
            let mut values = device_observations(&self.inner)?;
            let observed_at_ms = values[0].observed_at_ms;
            let capture = |data| Snapshot {
                schema_version: 1,
                observed_at_ms,
                data,
            };
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
        self.replica
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .take();
        self.inner.cancel_sign_in();
    }
}

fn device_observations(
    identity: &IdentityClient,
) -> Result<Vec<nddev_device_sync_domain::state::Snapshot>, VaultError> {
    use nddev_device_sync_domain::state::{Snapshot, State};
    let view = identity.view();
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
    let values = vec![
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
    Ok(values)
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
