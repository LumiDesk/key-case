package top.talyra42.keycase.data

import android.content.Context
import android.net.Uri
import java.io.ByteArrayOutputStream

/**
 * File I/O for encrypted backups. The ViewModel passes vault bytes and settings;
 * this class never sees decrypted item data.
 */
class VaultBackupService(private val context: Context) {
    fun export(uri: Uri, bytes: ByteArray) {
        context.contentResolver.openOutputStream(uri)?.use { out ->
            out.write(bytes)
            out.flush()
        } ?: error("无法写入备份文件")
    }

    fun readLimited(uri: Uri, maxBytes: Int = MAX_IMPORT_BYTES): ByteArray {
        val input = context.contentResolver.openInputStream(uri)
            ?: error("无法读取文件")
        return input.use { stream ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            var total = 0
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                total += read
                if (total > maxBytes) {
                    error("文件过大（上限 ${maxBytes / (1024 * 1024)} MB）")
                }
                out.write(buffer, 0, read)
            }
            out.toByteArray()
        }
    }

    fun writeSnapshot(treeUri: String, bytes: ByteArray): String =
        AutoBackupManager.write(context, treeUri, bytes)

    companion object {
        const val MAX_IMPORT_BYTES = 64 * 1024 * 1024
    }
}
