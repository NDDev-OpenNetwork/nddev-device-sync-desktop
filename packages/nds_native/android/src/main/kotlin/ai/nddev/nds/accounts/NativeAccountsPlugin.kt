package ai.nddev.nds.accounts

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin

class NativeAccountsPlugin : FlutterPlugin {
    companion object {
        init { System.loadLibrary("nds_native") }
        @JvmStatic external fun initializeKeyring(context: Context)
        @JvmStatic external fun initializeTls(context: Context)
    }
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        initializeKeyring(binding.applicationContext)
        initializeTls(binding.applicationContext)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
