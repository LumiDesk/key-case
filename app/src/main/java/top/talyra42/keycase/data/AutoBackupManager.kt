package top.talyra42.keycase.data

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Writes encrypted vault snapshots into a user-selected SAF folder.
 *
 * The selected tree is persisted by the activity; this object only creates the
 * KeyCase subfolder, writes one snapshot, and keeps the latest ten files.
 */
object AutoBackupManager {
    const val DIRECTORY_NAME = "KeyCase"
    private const val MAX_BACKUPS = 10

    fun displayName(context: Context, treeUri: String): String? = runCatching {
        DocumentFile.fromTreeUri(context, Uri.parse(treeUri))?.name
    }.getOrNull()

    fun write(context: Context, treeUri: String, bytes: ByteArray): String {
        val root = DocumentFile.fromTreeUri(context, Uri.parse(treeUri))
            ?: error("备份目录不可用")
        if (!root.canWrite()) error("没有备份目录写入权限")
        val directory = root.findFile(DIRECTORY_NAME)
            ?: root.createDirectory(DIRECTORY_NAME)
            ?: error("无法创建 KeyCase 文件夹")
        val stamp = SimpleDateFormat("yyyyMMdd-HHmmss-SSS", Locale.US).format(Date())
        val filename = "keycase-$stamp.kcbackup"
        val file = directory.createFile("application/octet-stream", filename)
            ?: error("无法创建备份文件")
        try {
            context.contentResolver.openOutputStream(file.uri)?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: error("无法写入备份文件")
        } catch (e: Exception) {
            runCatching { file.delete() }
            throw e
        }
        prune(directory)
        return filename
    }

    private fun prune(directory: DocumentFile) {
        val backups = directory.listFiles()
            .filter { it.isFile && it.name?.endsWith(".kcbackup") == true }
            // Filenames embed a sortable timestamp; provider lastModified values
            // are often coarse or zero, which could delete the newest backup.
            .sortedByDescending { it.name.orEmpty() }
        backups.drop(MAX_BACKUPS).forEach { runCatching { it.delete() } }
    }
}
