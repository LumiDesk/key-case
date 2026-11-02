package top.talyra42.keycase

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 唯一的原生桥入口。Flutter 侧只有 [NativeBridge] 一个 MethodChannel。
 *
 * 目前只处理两件事：截屏保护开关与 Keystore 包裹的 vault key。
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureScreen" -> {
                        val enabled = call.arguments as? Boolean ?: false
                        runOnUiThread { applySecureFlag(enabled) }
                        result.success(null)
                    }

                    "storeVaultKey" -> {
                        val key = call.argument<ByteArray>("key")
                        val vaultId = call.argument<String>("vaultId")
                        if (key == null || vaultId == null) {
                            result.error("bad_arguments", "key/vaultId required", null)
                        } else {
                            result.success(VaultKeyStore.store(this, key, vaultId))
                        }
                    }

                    "readVaultKey" -> {
                        val vaultId = call.argument<String>("vaultId")
                        if (vaultId == null) {
                            result.error("bad_arguments", "vaultId required", null)
                        } else {
                            result.success(VaultKeyStore.read(this, vaultId))
                        }
                    }

                    "clearVaultKey" -> {
                        VaultKeyStore.clear(this)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun applySecureFlag(enabled: Boolean) {
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    companion object {
        private const val CHANNEL = "top.talyra42.keycase/native"
    }
}
