use flutter_rust_bridge::frb;
#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
use nddev_device_sync_agent::NativeAgent;
use nddev_device_sync_agent::view::{AgentError, ModuleState};

#[frb(opaque)]
pub struct LocalAgent {
    #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
    inner: NativeAgent,
}

#[frb(sync)]
pub fn supports_local_agent() -> bool {
    cfg!(any(
        target_os = "linux",
        target_os = "macos",
        target_os = "windows"
    ))
}

impl LocalAgent {
    pub fn discover() -> Result<Self, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            Ok(Self {
                inner: NativeAgent::discover()?,
            })
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            Err(AgentError::UnsupportedPlatform)
        }
    }
    #[frb(sync)]
    pub fn close(&self) {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        self.inner.close();
    }
    #[frb(sync)]
    pub fn modules(&self) -> Result<Vec<ModuleState>, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            Ok(self.inner.modules())
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            Err(AgentError::UnsupportedPlatform)
        }
    }
    pub async fn system_info(
        &self,
    ) -> Result<nddev_device_sync_agent::view::sysinfo::SystemSnapshot, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            self.inner.system_info().await
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            Err(AgentError::UnsupportedPlatform)
        }
    }
    pub async fn clipboard_entries(
        &self,
        before: Option<u64>,
    ) -> Result<nddev_device_sync_agent::view::clipboard::Page, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            self.inner.clipboard_entries(before).await
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            let _ = (before);
            Err(AgentError::UnsupportedPlatform)
        }
    }
    pub async fn clipboard_content(&self, entry: u64, mime: String) -> Result<Vec<u8>, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            self.inner.clipboard_content(entry, mime).await
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            let _ = (entry, mime);
            Err(AgentError::UnsupportedPlatform)
        }
    }
    pub async fn cleaner_diagnostics(
        &self,
    ) -> Result<nddev_device_sync_agent::view::cleaner::Diagnostics, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            self.inner.cleaner_diagnostics().await
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            Err(AgentError::UnsupportedPlatform)
        }
    }
    pub async fn cleaner_preview(
        &self,
    ) -> Result<nddev_device_sync_agent::view::cleaner::CleanerRunSummary, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            self.inner.cleaner_preview().await
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            Err(AgentError::UnsupportedPlatform)
        }
    }
    pub async fn cleaner_last_run(
        &self,
    ) -> Result<nddev_device_sync_agent::view::cleaner::CleanerRunSummary, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            self.inner.cleaner_last_run().await
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            Err(AgentError::UnsupportedPlatform)
        }
    }
    pub async fn update_plan(
        &self,
    ) -> Result<nddev_device_sync_agent::view::updater::Plan, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            self.inner.update_plan().await
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            Err(AgentError::UnsupportedPlatform)
        }
    }
    pub async fn update_last_run(
        &self,
    ) -> Result<nddev_device_sync_agent::view::updater::UpdateRunSummary, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            self.inner.update_last_run().await
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            Err(AgentError::UnsupportedPlatform)
        }
    }
    pub async fn repository_status(
        &self,
        path: String,
    ) -> Result<nddev_device_sync_agent::view::gds::Status, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            self.inner
                .repository_status(std::path::Path::new(&path))
                .await
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            let _ = (path);
            Err(AgentError::UnsupportedPlatform)
        }
    }
    pub async fn remote_sessions(
        &self,
    ) -> Result<nddev_device_sync_agent::view::rds::RemoteSnapshot, AgentError> {
        #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
        {
            self.inner.remote_sessions().await
        }
        #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
        {
            Err(AgentError::UnsupportedPlatform)
        }
    }
}

/// Presentation access to the provider's opaque data-carrying enum. The
/// canonical enum remains in updater; no DTO is copied or serialized to JSON.
#[frb(sync)]
pub fn update_action_kind(action: &nddev_device_sync_updater::view::Action) -> String {
    use nddev_device_sync_updater::view::Action;
    match action {
        Action::GdsInstall { .. } => "gds_install",
        Action::VerifiedApplications => "verified_applications",
        Action::AptObserve => "apt_observe",
        Action::ToolchainObserve => "toolchain_observe",
        Action::Homebrew => "homebrew",
        Action::Flatpak => "flatpak",
    }
    .into()
}

#[frb(sync)]
pub fn update_action_platform(action: &nddev_device_sync_updater::view::Action) -> Option<String> {
    match action {
        nddev_device_sync_updater::view::Action::GdsInstall { platform } => Some(platform.clone()),
        _ => None,
    }
}
