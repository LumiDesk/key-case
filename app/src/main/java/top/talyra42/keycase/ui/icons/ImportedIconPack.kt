package top.talyra42.keycase.ui.icons

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import java.util.zip.ZipInputStream

/**
 * Imports Aegis-style icon packs (ZIP + pack.json). Bitmap entries are copied
 * into app-private storage; when the user selects one it is embedded into the
 * vault item as a custom image, so backups stay self-contained.
 */
object ImportedIconPack {
    data class PackIcon(
        val name: String,
        val issuer: String?,
        val file: File,
        val packName: String,
    )

    data class ImportResult(
        val imported: Int,
        val skipped: Int,
    )

    fun list(context: Context): List<PackIcon> {
        val root = root(context)
        val result = mutableListOf<PackIcon>()
        root.listFiles()?.filter { it.isDirectory }?.forEach { dir ->
            runCatching {
                val manifest = JSONObject(File(dir, "pack.json").readText())
                val packName = manifest.optString("name").ifBlank { dir.name }
                val icons = manifest.optJSONArray("icons") ?: return@runCatching
                for (i in 0 until icons.length()) {
                    val obj = icons.optJSONObject(i) ?: continue
                    val name = obj.optString("name")
                    val filename = obj.optString("filename")
                    if (name.isBlank() || filename.isBlank()) continue
                    val file = File(dir, filename.substringAfterLast('/'))
                    if (file.isFile) {
                        result += PackIcon(name, issuerOf(obj), file, packName)
                    }
                }
            }
        }
        return result.sortedBy { it.name.lowercase() }
    }

    fun delete(context: Context, packName: String): Boolean {
        var deleted = false
        root(context).listFiles()?.filter { it.isDirectory }?.forEach { dir ->
            runCatching {
                val manifest = JSONObject(File(dir, "pack.json").readText())
                val name = manifest.optString("name").ifBlank { dir.name }
                if (name == packName) deleted = dir.deleteRecursively() || deleted
            }
        }
        return deleted
    }

    fun import(context: Context, uri: Uri): ImportResult {
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: error("Could not read the icon pack")
        val entries = readEntries(bytes)
        val manifestEntry = entries.entries.firstOrNull {
            it.key.substringAfterLast('/') == "pack.json"
        } ?: error("pack.json is missing")
        val manifest = JSONObject(manifestEntry.value.toString(Charsets.UTF_8))
        val icons = manifest.optJSONArray("icons") ?: error("No icons in pack.json")
        val packDir = File(root(context), "pack-${UUID.randomUUID()}")
        packDir.mkdirs()
        File(packDir, "pack.json").writeBytes(manifestEntry.value)

        var imported = 0
        var skipped = 0
        for (i in 0 until icons.length()) {
            val obj = icons.optJSONObject(i) ?: continue
            val filename = obj.optString("filename")
            if (filename.isBlank()) {
                skipped++
                continue
            }
            val data = findEntry(entries, filename)
            if (data == null || BitmapFactory.decodeByteArray(data, 0, data.size) == null) {
                skipped++
                continue
            }
            val target = File(packDir, filename.substringAfterLast('/'))
            target.writeBytes(data)
            imported++
        }
        if (imported == 0) {
            packDir.deleteRecursively()
            error("No bitmap icons found in this pack")
        }
        return ImportResult(imported, skipped)
    }

    fun encodeForVault(file: File, maxSize: Int = 192): String {
        val bitmap = BitmapFactory.decodeFile(file.absolutePath)
            ?: error("Could not read icon")
        val scale = minOf(1f, maxSize.toFloat() / maxOf(bitmap.width, bitmap.height))
        val scaled = if (scale < 1f) {
            android.graphics.Bitmap.createScaledBitmap(
                bitmap,
                (bitmap.width * scale).toInt().coerceAtLeast(1),
                (bitmap.height * scale).toInt().coerceAtLeast(1),
                true,
            )
        } else {
            bitmap
        }
        val out = ByteArrayOutputStream()
        scaled.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
        return android.util.Base64.encodeToString(out.toByteArray(), android.util.Base64.NO_WRAP)
    }

    private fun readEntries(bytes: ByteArray): Map<String, ByteArray> {
        val result = LinkedHashMap<String, ByteArray>()
        var total = 0
        ZipInputStream(bytes.inputStream()).use { zip ->
            var entry = zip.nextEntry
            while (entry != null) {
                if (!entry.isDirectory) {
                    val data = zip.readBytes()
                    total += data.size
                    if (total > 30 * 1024 * 1024) error("Icon pack is too large")
                    result[entry.name] = data
                }
                entry = zip.nextEntry
            }
        }
        return result
    }

    private fun findEntry(entries: Map<String, ByteArray>, filename: String): ByteArray? {
        entries[filename]?.let { return it }
        val base = filename.substringAfterLast('/')
        return entries.entries.firstOrNull {
            it.key.substringAfterLast('/') == base
        }?.value
    }

    private fun issuerOf(obj: JSONObject): String? {
        val array: JSONArray? = obj.optJSONArray("issuer")
        if (array != null) {
            for (i in 0 until array.length()) {
                val value = array.optString(i)
                if (value.isNotBlank()) return value
            }
        }
        return obj.optString("issuer").takeIf { it.isNotBlank() }
    }

    private fun root(context: Context): File =
        File(context.filesDir, "iconpacks").apply { mkdirs() }
}
