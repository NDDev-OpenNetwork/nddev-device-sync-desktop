use jni::{
    EnvUnowned, jni_mangle,
    objects::{JClass, JObject},
};

#[jni_mangle("ai.nddev.nds.accounts.NativeAccountsPlugin")]
pub fn initializeTls<'local>(
    environment: EnvUnowned<'local>,
    _class: JClass<'local>,
    context: JObject<'local>,
) {
    nddev_device_sync_accounts::android::initialize_tls(environment, context);
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_ai_nddev_nds_accounts_NativeAccountsPlugin_initializeKeyring(
    env: jni_legacy::JNIEnv<'_>,
    class: jni_legacy::objects::JObject<'_>,
    context: jni_legacy::objects::JObject<'_>,
) {
    nddev_device_sync_accounts::android::initialize_keyring(env, class, context);
}
