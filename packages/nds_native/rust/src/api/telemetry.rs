//! Process configuration and FFI only; event policy and diagnostics belong to SDK.
use flutter_rust_bridge::frb;
use nddev_device_sync_telemetry::{
    Config, DebugWindow, Logger,
    view::{ClientLifecycle, DebugScope, DiagnosticsError, FailureKind, LocalDiagnostics},
};
use std::{
    sync::{Mutex, MutexGuard, OnceLock},
    time::Duration,
};

static LOGGER: OnceLock<Option<Mutex<Logger>>> = OnceLock::new();
fn logger() -> Option<MutexGuard<'static, Logger>> {
    LOGGER
        .get()?
        .as_ref()
        .map(|logger| logger.lock().unwrap_or_else(|e| e.into_inner()))
}

#[frb(init)]
pub fn init_app() -> Result<(), DiagnosticsError> {
    LOGGER.get_or_init(|| {
        nddev_device_sync_telemetry::install(Config {
            service: "nddev-device-sync-client".into(),
            version: env!("CARGO_PKG_VERSION").into(),
            repository: "NDDev-OpenNetwork/nddev-device-sync-desktop".into(),
            commit: crate::provenance::source_commit().into(),
            channel: "alpha".into(),
            standards: "v0.0.1-alpha.9".into(),
            environment: if cfg!(debug_assertions)
                || crate::provenance::source_commit() == "unknown"
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
        .map(Mutex::new)
    });
    // An unavailable OS sink is explicitly degraded; identity may still work.
    Ok(())
}

#[frb(sync)]
pub fn client_diagnostics() -> LocalDiagnostics {
    logger().map_or_else(LocalDiagnostics::unavailable, |logger| {
        logger.control.diagnostics()
    })
}

#[frb(sync)]
pub fn configure_debug(scope: DebugScope, seconds: u16) -> Result<(), DiagnosticsError> {
    if seconds > 300 || (seconds > 0 && !matches!(scope, DebugScope::Http | DebugScope::Io)) {
        return Err(DiagnosticsError::InvalidInput);
    }
    let logger = logger().ok_or(DiagnosticsError::Unavailable)?;
    logger
        .control
        .set_debug((seconds > 0).then(|| DebugWindow {
            scope: scope.as_str().into(),
            duration: Duration::from_secs(u64::from(seconds)),
            events: 100,
        }))
        .map_err(|_| DiagnosticsError::Unavailable)
}

/// True means the SDK accepted the call, not that an external collector received it.
#[frb(sync)]
pub fn record_client_failure(kind: FailureKind) -> bool {
    let Some(logger) = logger() else {
        return false;
    };
    if logger.control.output_health().terminating {
        return false;
    }
    logger.control.report_failure(kind);
    true
}

#[frb(sync)]
pub fn record_client_lifecycle(state: ClientLifecycle) -> bool {
    let Some(logger) = logger() else {
        return false;
    };
    if logger.control.output_health().terminating {
        return false;
    }
    logger.control.report_client_lifecycle(state);
    true
}

/// Runs on the bridge worker, never synchronously on Flutter's frame thread.
pub fn shutdown_telemetry() -> LocalDiagnostics {
    logger().map_or_else(LocalDiagnostics::unavailable, |mut logger| {
        logger.shutdown();
        logger.control.diagnostics()
    })
}

#[cfg(all(test, unix))]
mod tests {
    #[test]
    fn missing_console_preserves_identity_and_reports_diagnostic_unavailability() {
        const CHILD: &str = "NDS_TEST_CLOSED_STDOUT_CHILD";
        if std::env::var_os(CHILD).is_some() {
            use std::os::fd::{FromRawFd, OwnedFd};
            unsafe {
                drop(OwnedFd::from_raw_fd(1));
            }
            super::init_app().unwrap();
            let status = super::client_diagnostics();
            assert!(!status.sink_initialized && !status.debug_enabled);
            assert!(status.write_failures.is_none() && status.dropped_events.is_none());
            crate::api::identity::NdsClient::new("https://example.invalid".into()).unwrap();
            assert_eq!(
                super::configure_debug(super::DebugScope::Http, 30),
                Err(super::DiagnosticsError::Unavailable)
            );
            assert!(!super::record_client_failure(
                super::FailureKind::NativeBridge
            ));
            std::process::exit(0);
        }
        let output = std::process::Command::new(std::env::current_exe().unwrap())
            .args(["--exact", "api::telemetry::tests::missing_console_preserves_identity_and_reports_diagnostic_unavailability", "--nocapture"])
            .env(CHILD, "1").output().unwrap();
        assert!(
            output.status.success(),
            "isolated missing-console startup failed"
        );
    }
}
