use flutter_rust_bridge::frb;
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
    pub async fn refresh_devices(&self) -> Result<View, ClientError> {
        self.inner.refresh_devices().await
    }
    pub async fn enroll_device(&self, name: String) -> Result<View, ClientError> {
        self.inner.enroll_device(name).await
    }
    pub async fn revoke_device(&self, id: String) -> Result<View, ClientError> {
        self.inner.revoke_device(id).await
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
