//! Browser composition only. The vault module owns all journal SQL and I/O;
//! these exports let its dedicated worker load the shared application bundle.
use nddev_device_sync_vault::browser as journal;
use wasm_bindgen::prelude::*;
fn failure(_: nddev_device_sync_vault::Error) -> JsValue {
    js_sys::Error::new("vault_dependency_unavailable").into()
}
pub(crate) fn configure() -> Result<(), nddev_device_sync_vault::Error> {
    journal::configure_worker("/nds-vault-worker.js", "/pkg/nds_native.js")
}
#[wasm_bindgen]
pub async fn nds_journal_open(scope: String) -> Result<(), JsValue> {
    journal::worker_open(scope).await.map_err(failure)
}
#[wasm_bindgen]
pub async fn nds_journal_resume() -> Result<(), JsValue> {
    journal::worker_resume().await.map_err(failure)
}
#[wasm_bindgen]
pub fn nds_journal_pause() -> Result<(), JsValue> {
    journal::worker_pause().map_err(failure)
}
#[wasm_bindgen]
pub fn nds_journal_execute(command: String) -> Result<String, JsValue> {
    journal::worker_execute(&command).map_err(failure)
}
