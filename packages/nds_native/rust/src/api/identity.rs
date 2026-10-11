use flutter_rust_bridge::frb;
use nddev_device_sync_accounts::{
    IdentityClient,
    view::{ClientError, PasskeyView, View},
};
use nddev_device_sync_vault::{
    VaultClient,
    view::{RecordPage, StatePage, VaultError, VaultView},
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
    delivery: Mutex<Option<super::telemetry::Delivery>>,
    clipboard: nddev_device_sync_clipboard::os::TextClipboard,
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
            delivery: Mutex::default(),
            clipboard: Default::default(),
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
    pub async fn passkeys(&self) -> Result<Vec<PasskeyView>, ClientError> {
        self.inner.passkeys().await
    }
    pub async fn revoke_passkey(&self, id: String) -> Result<View, ClientError> {
        let view = self.inner.revoke_passkey(id).await?;
        if !view.authenticated {
            self.delivery
                .lock()
                .unwrap_or_else(|error| error.into_inner())
                .take();
            self.stop_replica().await;
            self.vault.lock().await.take();
        }
        Ok(view)
    }
    pub async fn poll_passkey(&self) -> Result<View, ClientError> {
        self.inner.poll_passkey().await
    }
    pub async fn poll_github(&self) -> Result<View, ClientError> {
        self.inner.poll_github().await
    }
    pub async fn logout(&self) -> Result<View, ClientError> {
        self.delivery
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .take();
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
        {
            let mut delivery = self
                .delivery
                .lock()
                .unwrap_or_else(|error| error.into_inner());
            if delivery.as_ref().is_none_or(|delivery| delivery.finished()) {
                delivery.take();
                *delivery = super::telemetry::start_delivery(
                    self.inner.clone(),
                    self.foreground.load(Ordering::Relaxed),
                );
            }
        }
        self.start_replica()
            .await
            .map_err(|_| ClientError::Transport)?;
        Ok(view)
    }
    pub async fn revoke_device(&self, id: String) -> Result<View, ClientError> {
        let view = self.inner.revoke_device(id).await?;
        if view
            .devices
            .iter()
            .any(|device| device.is_current && device.revoked)
        {
            self.delivery
                .lock()
                .unwrap_or_else(|error| error.into_inner())
                .take();
            self.stop_replica().await;
        }
        Ok(view)
    }
    #[frb(sync)]
    pub fn set_foreground(&self, active: bool) {
        self.foreground.store(active, Ordering::Relaxed);
        if let Some(delivery) = &*self
            .delivery
            .lock()
            .unwrap_or_else(|error| error.into_inner())
        {
            delivery.foreground(active);
        }
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
    pub async fn vault_records(&self, after: String) -> Result<RecordPage, VaultError> {
        observe("vault.records", async {
            self.vault().await?.records(after).await
        })
        .await
    }
    pub async fn vault_save(
        &self,
        id: Option<String>,
        expected_revision: u64,
        title: String,
        username: String,
        secret: String,
    ) -> Result<String, VaultError> {
        let result = observe("vault.record.save", async {
            self.vault()
                .await?
                .save_record(
                    id,
                    expected_revision,
                    title,
                    username,
                    Zeroizing::new(secret),
                )
                .await
        })
        .await?;
        self.wake_replica();
        Ok(result)
    }
    pub async fn vault_delete(
        &self,
        id: String,
        expected_revision: u64,
    ) -> Result<String, VaultError> {
        let result = observe("vault.record.delete", async {
            self.vault()
                .await?
                .delete_record(id, expected_revision)
                .await
        })
        .await?;
        self.wake_replica();
        Ok(result)
    }
    pub async fn vault_resolve(
        &self,
        id: String,
        expected_revision: u64,
        expected_cursor: u64,
        use_conflict: bool,
    ) -> Result<String, VaultError> {
        let result = observe("vault.record.resolve", async {
            self.vault()
                .await?
                .resolve_record(id, expected_revision, expected_cursor, use_conflict)
                .await
        })
        .await?;
        self.wake_replica();
        Ok(result)
    }
    fn wake_replica(&self) {
        if self.foreground.load(Ordering::Relaxed)
            && let Some(replica) = &*self
                .replica
                .lock()
                .unwrap_or_else(|error| error.into_inner())
        {
            replica.active.send_replace(true);
        }
    }
    pub async fn clipboard_snapshot(
        &self,
    ) -> Result<nddev_device_sync_vault::view::ClipboardView, VaultError> {
        Ok(self
            .vault()
            .await?
            .clipboard()
            .await?
            .map_or_else(Default::default, |(metadata, _)| metadata))
    }
    pub async fn clipboard_publish_text(&self, text: String) -> Result<String, VaultError> {
        let result = observe("clipboard.publish", async {
            self.vault()
                .await?
                .share_clipboard(Zeroizing::new(text))
                .await
        })
        .await?;
        self.wake_replica();
        Ok(result)
    }
    pub async fn clipboard_publish_archive(
        &self,
        agent: &super::modules::LocalAgent,
        entry: u64,
        mime: String,
    ) -> Result<String, VaultError> {
        if !matches!(
            mime.as_str(),
            "text/plain" | "text/plain;charset=utf-8" | "text/plain;charset=UTF-8"
        ) {
            return Err(VaultError::Invalid);
        }
        let result = observe("clipboard.archive.publish", async {
            let bytes = Zeroizing::new(
                agent
                    .clipboard_content(entry, mime)
                    .await
                    .map_err(|_| VaultError::Unavailable)?,
            );
            if bytes.len() > 8192 {
                return Err(VaultError::Invalid);
            }
            let text =
                Zeroizing::new(String::from_utf8(bytes.to_vec()).map_err(|_| VaultError::Invalid)?);
            self.vault().await?.share_clipboard(text).await
        })
        .await?;
        self.wake_replica();
        Ok(result)
    }
    pub async fn clipboard_publish_native(&self) -> Result<String, ClientError> {
        #[cfg(target_os = "android")]
        {
            if !self.foreground.load(Ordering::Relaxed) {
                return Err(ClientError::Busy);
            }
            // Preserve the native allowlisted refusal reason, never its content.
            let text = self
                .clipboard
                .read()
                .await
                .map_err(|error| ClientError::Server(error.to_string()))?;
            let vault = self
                .vault()
                .await
                .map_err(|error| ClientError::Server(error.code()))?;
            let result = vault
                .share_clipboard(text)
                .await
                .map_err(|error| ClientError::Server(error.code()))?;
            self.wake_replica();
            Ok(result)
        }
        #[cfg(not(target_os = "android"))]
        {
            Err(ClientError::Server("clipboard_unsupported".into()))
        }
    }
    pub async fn clipboard_copy(&self) -> Result<(), VaultError> {
        observe("clipboard.copy", async {
            let (_, text) = self
                .vault()
                .await?
                .clipboard()
                .await?
                .ok_or(VaultError::Invalid)?;
            self.clipboard
                .write(text, false)
                .await
                .map_err(|_| VaultError::Unavailable)
        })
        .await
    }
    pub async fn vault_copy_secret(&self, id: String) -> Result<(), VaultError> {
        observe("vault.secret.copy", async {
            let text = self.vault().await?.native_secret(id).await?;
            self.clipboard
                .write(text, true)
                .await
                .map_err(|_| VaultError::Unavailable)
        })
        .await
    }
    pub async fn incidents(&self, after: String) -> Result<IncidentPage, ClientError> {
        let reply = self
            .inner
            .sync_request(nddev_device_sync_accounts::SyncRequest::Incidents { after })
            .await?;
        let page: nddev_device_sync_accounts::observability_wire::IncidentPage =
            serde_json::from_slice(&reply.body).map_err(|_| ClientError::InvalidResponse)?;
        if page.incidents.len() > 50 {
            return Err(ClientError::InvalidResponse);
        }
        let mut incidents = Vec::new();
        for incident in page.incidents {
            incidents.push(incident_view(incident)?);
        }
        Ok(IncidentPage {
            incidents,
            next_cursor: page.next_cursor.unwrap_or_default(),
            generated_at: page.generated_at,
        })
    }
    pub async fn incident_action(
        &self,
        id: String,
        revision: u64,
        silence_seconds: u32,
    ) -> Result<IncidentView, ClientError> {
        if !(1..=9_007_199_254_740_991).contains(&revision) || silence_seconds > 86_400 {
            return Err(ClientError::InvalidInput);
        }
        let operation_id = uuid::Uuid::now_v7().to_string();
        let expected_revision = revision as i64;
        let body = if silence_seconds == 0 {
            serde_json::to_vec(
                &nddev_device_sync_accounts::observability_wire::IncidentAction {
                    operation_id,
                    expected_revision,
                },
            )
        } else {
            let until = (time::OffsetDateTime::now_utc()
                + time::Duration::seconds(i64::from(silence_seconds)))
            .format(&time::format_description::well_known::Rfc3339)
            .map_err(|_| ClientError::InvalidInput)?;
            serde_json::to_vec(
                &nddev_device_sync_accounts::observability_wire::SilenceAction {
                    operation_id,
                    expected_revision,
                    until,
                },
            )
        }
        .map_err(|_| ClientError::InvalidInput)?;
        let reply = self
            .inner
            .sync_request(nddev_device_sync_accounts::SyncRequest::IncidentAction {
                id,
                silence: silence_seconds > 0,
                body,
            })
            .await?;
        incident_view(
            serde_json::from_slice(&reply.body).map_err(|_| ClientError::InvalidResponse)?,
        )
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
    pub fn delivery_snapshot(&self) -> super::telemetry::DeliveryView {
        self.delivery
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .as_ref()
            .map_or_else(Default::default, |delivery| delivery.snapshot())
    }
    #[frb(sync)]
    pub fn cancel(&self) {
        self.delivery
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .take();
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
        nddev_device_sync_accounts::android::private_data_directory()
            .map_err(|_| VaultError::Unavailable)
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

#[derive(Clone)]
pub struct IncidentView {
    pub id: String,
    pub service: String,
    pub kind: String,
    pub severity: String,
    pub state: String,
    pub revision: u64,
    pub occurrences: u64,
    pub first_seen: String,
    pub last_seen: String,
    pub silenced_until: String,
}
#[derive(Clone)]
pub struct IncidentPage {
    pub incidents: Vec<IncidentView>,
    pub next_cursor: String,
    pub generated_at: String,
}
fn incident_view(
    value: nddev_device_sync_accounts::observability_wire::Incident,
) -> Result<IncidentView, ClientError> {
    fn tag(value: impl serde::Serialize) -> Result<String, ClientError> {
        serde_json::to_value(value)
            .ok()
            .and_then(|value| value.as_str().map(str::to_owned))
            .ok_or(ClientError::InvalidResponse)
    }
    if value.revision < 1 || value.occurrences < 1 {
        return Err(ClientError::InvalidResponse);
    }
    Ok(IncidentView {
        id: value.incident_id,
        service: value.service_name,
        kind: tag(value.kind)?,
        severity: tag(value.severity)?,
        state: tag(value.state)?,
        revision: value.revision as u64,
        occurrences: value.occurrences as u64,
        first_seen: value.first_seen,
        last_seen: value.last_seen,
        silenced_until: value.silenced_until.unwrap_or_default(),
    })
}

#[frb(sync)]
pub fn supports_native_clipboard() -> bool {
    cfg!(any(
        target_os = "linux",
        target_os = "macos",
        target_os = "windows",
        target_os = "android"
    ))
}

#[frb(sync)]
pub fn new_vault_record_id() -> String {
    uuid::Uuid::new_v4().to_string()
}
