use flutter_rust_bridge::frb;
use nddev_device_sync_telemetry::{Config, DebugWindow, Logger};
use std::{
    sync::{Mutex, OnceLock},
    time::Duration,
};

static LOGGER: OnceLock<Option<Mutex<Logger>>> = OnceLock::new();
use nddev_device_sync_accounts::{
    IdentityClient,
    view::{ClientError, View},
};

#[frb(opaque)]
pub struct NdsClient {
    inner: IdentityClient,
}

impl NdsClient {
    pub fn new(endpoint: String) -> Result<Self, ClientError> {
        Ok(Self {
            inner: IdentityClient::new(&endpoint)?,
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
        self.inner.logout().await
    }
    #[frb(sync)]
    pub fn snapshot(&self) -> View {
        self.inner.view()
    }
    #[frb(sync)]
    pub fn cancel(&self) {
        self.inner.cancel_sign_in();
    }
    #[frb(sync)]
    pub fn enable_debug(&self, seconds: u16) -> Result<(), ClientError> {
        if seconds > 300 {
            return Err(ClientError::InvalidInput);
        }
        LOGGER
            .get()
            .and_then(Option::as_ref)
            .ok_or(ClientError::TelemetryUnavailable)?
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .control
            .set_debug((seconds > 0).then(|| DebugWindow {
                scope: "http".into(),
                duration: Duration::from_secs(u64::from(seconds)),
                events: 100,
            }))
            .map_err(|_| ClientError::TelemetryUnavailable)
    }
    #[frb(sync)]
    pub fn debug_enabled(&self) -> bool {
        LOGGER.get().and_then(Option::as_ref).is_some_and(|logger| {
            logger
                .lock()
                .unwrap_or_else(|error| error.into_inner())
                .control
                .debug_active()
        })
    }
}

#[frb(init)]
pub fn init_app() -> Result<(), ClientError> {
    LOGGER.get_or_init(|| {
        let logger = nddev_device_sync_telemetry::install(Config {
            service: "nddev-device-sync-client".into(),
            version: env!("CARGO_PKG_VERSION").into(),
            repository: "NDDev-OpenNetwork/nddev-device-sync-desktop".into(),
            commit: option_env!("NDS_SOURCE_COMMIT").unwrap_or("unknown").into(),
            channel: "alpha".into(),
            standards: "v0.0.1-alpha.9".into(),
            environment: if cfg!(debug_assertions)
                || option_env!("NDS_SOURCE_COMMIT").unwrap_or("unknown") == "unknown"
            {
                "development"
            } else {
                "client"
            }
            .into(),
            target_prefixes: vec![
                "nds_accounts".into(),
                "nds_native".into(),
                "nddev_device_sync_agent".into(),
                "nddev_device_sync_adapter_io".into(),
                "nddev_device_sync_sysinfo".into(),
                "nddev_device_sync_clipboard".into(),
                "nddev_device_sync_cleaner".into(),
                "nddev_device_sync_updater".into(),
                "nddev_device_sync_gds".into(),
                "nddev_device_sync_rds".into(),
            ],
            default_module: "process".into(),
            debug: None,
        })
        .ok()
        .map(Mutex::new);
        // A GUI process may have no attached console. Record that explicitly; an
        // unavailable diagnostics sink must not prevent native identity from starting.
        if logger.is_some() {
            tracing::event!(target: "nds_native", tracing::Level::INFO, {
                event.name = "process.started", outcome = "ready"
            });
        }
        logger
    });
    Ok(())
}

/// Read-only presentation of common SDK health, never a delivery receipt.
#[derive(Clone)]
pub struct ClientDiagnostics {
    pub sink_initialized: bool,
    pub rejected_fields_or_events: Option<u64>,
    pub dropped_events: Option<u64>,
    pub pending_events: Option<u64>,
    pub write_failures: Option<u64>,
    pub terminating: Option<bool>,
    pub shutdown_incomplete: Option<bool>,
}

#[frb(sync)]
pub fn client_diagnostics() -> ClientDiagnostics {
    if let Some(logger) = LOGGER.get().and_then(Option::as_ref) {
        let logger = logger.lock().unwrap_or_else(|error| error.into_inner());
        let health = logger.control.output_health();
        ClientDiagnostics {
            sink_initialized: true,
            rejected_fields_or_events: Some(logger.control.rejected_fields_or_events()),
            dropped_events: Some(health.dropped_events),
            pending_events: Some(health.pending_events),
            write_failures: Some(health.write_failures),
            terminating: Some(health.terminating),
            shutdown_incomplete: Some(health.shutdown_incomplete),
        }
    } else {
        ClientDiagnostics {
            sink_initialized: false,
            rejected_fields_or_events: None,
            dropped_events: None,
            pending_events: None,
            write_failures: None,
            terminating: None,
            shutdown_incomplete: None,
        }
    }
}

#[cfg(all(test, unix))]
mod tests {
    #[test]
    fn missing_console_does_not_prevent_native_client_startup() {
        const CHILD: &str = "NDS_TEST_CLOSED_STDOUT_CHILD";
        if std::env::var_os(CHILD).is_some() {
            use std::os::fd::{FromRawFd, OwnedFd};
            // This isolated test child owns its process stdout. Close it only
            // after the test harness starts, then exit before harness output.
            unsafe {
                drop(OwnedFd::from_raw_fd(1));
            }
            super::init_app().unwrap();
            let status = super::client_diagnostics();
            assert!(!status.sink_initialized);
            assert!(status.write_failures.is_none() && status.dropped_events.is_none());
            let client = super::NdsClient::new("https://example.invalid".into()).unwrap();
            assert!(!client.debug_enabled());
            assert!(matches!(
                client.enable_debug(30),
                Err(super::ClientError::TelemetryUnavailable)
            ));
            std::process::exit(0);
        }
        let output = std::process::Command::new(std::env::current_exe().unwrap())
            .args([
                "--exact",
                "api::identity::tests::missing_console_does_not_prevent_native_client_startup",
                "--nocapture",
            ])
            .env(CHILD, "1")
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "isolated missing-console startup failed"
        );
    }
}
