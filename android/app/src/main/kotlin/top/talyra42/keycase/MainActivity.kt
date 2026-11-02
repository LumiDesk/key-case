package top.talyra42.keycase

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.view.WindowManager
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 唯一的原生桥入口。Flutter 侧只有 [NativeBridge] 一个 MethodChannel。
 *
 * 处理四件事：截屏保护、Keystore 包裹的 vault key、备份目录选择与写入。
 *
 * 必须继承 FlutterFragmentActivity：local_auth 的 BiometricPrompt 依赖
 * FragmentActivity，用 FlutterActivity 会直接抛异常、表现为「指纹验证未通过」。
 */
class MainActivity : FlutterFragmentActivity() {
    private var pendingFolderResult: MethodChannel.Result? = null

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

                    "pickBackupFolder" -> pickBackupFolder(result)

                    "writeBackupFile" -> {
                        val dirUri = call.argument<String>("dirUri")
                        val name = call.argument<String>("name")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (dirUri == null || name == null || bytes == null) {
                            result.error("bad_arguments", "dirUri/name/bytes required", null)
                        } else {
                            result.success(writeBackup(dirUri, name, bytes))
                        }
                    }

                    "listBackupFiles" -> {
                        val dirUri = call.argument<String>("dirUri")
                        if (dirUri == null) {
                            result.error("bad_arguments", "dirUri required", null)
                        } else {
                            result.success(listBackups(dirUri))
                        }
                    }

                    "deleteBackupFiles" -> {
                        val dirUri = call.argument<String>("dirUri")
                        val names = call.argument<List<String>>("names").orEmpty()
                        if (dirUri == null) {
                            result.error("bad_arguments", "dirUri required", null)
                        } else {
                            result.success(deleteBackups(dirUri, names))
                        }
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

    private fun pickBackupFolder(result: MethodChannel.Result) {
        if (pendingFolderResult != null) {
            result.error("busy", "folder picker already open", null)
            return
        }
        pendingFolderResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, REQUEST_PICK_FOLDER)
    }

    @Deprecated("Flutter embedding v2 still routes SAF results through onActivityResult")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK_FOLDER) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingFolderResult
        pendingFolderResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result?.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // 个别 ROM 不给持久授权；本次仍可用，下次需要重新选择。
        }
        val name = DocumentFile.fromTreeUri(this, uri)?.name ?: "备份目录"
        result?.success(mapOf("uri" to uri.toString(), "name" to name))
    }

    /** 备份统一放在所选目录下的 KeyCase 子目录，避免污染用户目录根。 */
    private fun backupFolder(dirUri: String): DocumentFile? {
        val tree = DocumentFile.fromTreeUri(this, Uri.parse(dirUri)) ?: return null
        return tree.findFile(FOLDER_NAME) ?: tree.createDirectory(FOLDER_NAME)
    }

    private fun writeBackup(dirUri: String, name: String, bytes: ByteArray): Boolean {
        return try {
            val folder = backupFolder(dirUri) ?: return false
            folder.findFile(name)?.delete()
            val file = folder.createFile("application/octet-stream", name) ?: return false
            contentResolver.openOutputStream(file.uri)?.use { it.write(bytes) } ?: return false
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun listBackups(dirUri: String): List<String> {
        return try {
            backupFolder(dirUri)
                ?.listFiles()
                ?.filter { it.isFile && it.name != null }
                ?.mapNotNull { it.name }
                ?.sortedDescending()
                ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun deleteBackups(dirUri: String, names: List<String>): Boolean {
        return try {
            val folder = backupFolder(dirUri) ?: return false
            for (name in names) {
                folder.findFile(name)?.delete()
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        private const val CHANNEL = "top.talyra42.keycase/native"
        private const val REQUEST_PICK_FOLDER = 4711
        private const val FOLDER_NAME = "KeyCase"
    }
}
