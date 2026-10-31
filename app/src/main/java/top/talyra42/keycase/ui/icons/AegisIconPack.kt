package top.talyra42.keycase.ui.icons

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import top.talyra42.keycase.ui.LetterAvatar
import top.talyra42.keycase.ui.avatarColor
import java.io.ByteArrayInputStream
import java.util.zip.ZipInputStream

/**
 * Minimal reader for Aegis icon packs. The built-in pack is a ZIP with a
 * pack.json manifest and monochrome SVGs. Simple Icons SVGs are a single path,
 * so we can turn them into Compose ImageVectors without an SVG library.
 */
object AegisIconPack {
    private const val ASSET = "iconpacks/aegis-simple-icons-v269.zip"

    private var zipBytes: ByteArray? = null
    private var index: Map<String, Entry>? = null
    private val vectorCache = mutableMapOf<String, ImageVector?>()
    private val lock = Any()

    private data class Entry(
        val name: String,
        val filename: String,
        val issuers: List<String>,
    )

    data class PackIcon(
        val name: String,
        val filename: String,
    )

    fun entries(context: Context): List<PackIcon> {
        val byFile = LinkedHashMap<String, PackIcon>()
        ensureIndex(context)?.values?.forEach { entry ->
            byFile.putIfAbsent(entry.filename, PackIcon(entry.name, entry.filename))
        }
        return byFile.values.sortedBy { it.name.lowercase() }
    }

    fun vectorFor(context: Context, filename: String, name: String): ImageVector? {
        if (filename.isBlank()) return null
        synchronized(lock) {
            if (vectorCache.containsKey(filename)) return vectorCache[filename]
        }
        val svg = readEntry(context, filename).orEmpty()
        val vector = parseSimpleIcon(name, svg)
        synchronized(lock) { vectorCache[filename] = vector }
        return vector
    }

    fun find(context: Context, label: String): ImageVector? {
        val key = normalize(label)
        if (key.isBlank()) return null
        val entries = ensureIndex(context) ?: return null
        val entry = entries[key]
            ?: entries.entries.firstOrNull { (candidate, _) ->
                candidate.length >= 3 && (key.contains(candidate) || candidate.contains(key))
            }?.value
            ?: return null
        synchronized(lock) {
            if (vectorCache.containsKey(entry.filename)) return vectorCache[entry.filename]
        }
        val svg = readEntry(context, entry.filename).orEmpty()
        val vector = parseSimpleIcon(entry.name, svg)
        synchronized(lock) { vectorCache[entry.filename] = vector }
        return vector
    }

    private fun ensureIndex(context: Context): Map<String, Entry>? = synchronized(lock) {
        index?.let { return it }
        val bytes = zipBytes ?: runCatching {
            context.assets.open(ASSET).use { it.readBytes() }
        }.getOrNull() ?: return null
        zipBytes = bytes

        val manifest = runCatching {
            ZipInputStream(ByteArrayInputStream(bytes)).use { zip ->
                var entry = zip.nextEntry
                while (entry != null) {
                    if (entry.name == "pack.json") {
                        return@use zip.readBytes().toString(Charsets.UTF_8)
                    }
                    entry = zip.nextEntry
                }
                null
            }
        }.getOrNull() ?: return null

        val result = mutableMapOf<String, Entry>()
        runCatching {
            val icons = JSONObject(manifest).getJSONArray("icons")
            for (i in 0 until icons.length()) {
                val obj = icons.getJSONObject(i)
                val name = obj.optString("name")
                val filename = obj.optString("filename")
                if (filename.isBlank()) continue
                val issuers = obj.optJSONArray("issuer")
                val issuerList = buildList {
                    if (issuers != null) {
                        for (j in 0 until issuers.length()) {
                            val issuer = issuers.optString(j)
                            if (issuer.isNotBlank()) add(issuer)
                        }
                    }
                }
                val entry = Entry(name, filename, issuerList)
                result.putIfAbsent(normalize(name), entry)
                issuerList.forEach { result.putIfAbsent(normalize(it), entry) }
            }
        }
        index = result
        return result
    }

    private fun readEntry(context: Context, filename: String): String? = synchronized(lock) {
        val bytes = zipBytes ?: runCatching {
            context.assets.open(ASSET).use { it.readBytes() }
        }.getOrNull() ?: return null
        zipBytes = bytes
        runCatching {
            ZipInputStream(ByteArrayInputStream(bytes)).use { zip ->
                var entry = zip.nextEntry
                while (entry != null) {
                    if (entry.name == filename) {
                        return@use zip.readBytes().toString(Charsets.UTF_8)
                    }
                    entry = zip.nextEntry
                }
                null
            }
        }.getOrNull()
    }

    private fun parseSimpleIcon(name: String, svg: String): ImageVector? {
        if (svg.isBlank()) return null
        val viewBox = Regex("""viewBox="([^"]+)"""").find(svg)?.groupValues?.get(1)
            ?.trim()?.split(Regex("""[\s,]+"""))?.mapNotNull { it.toFloatOrNull() }
        val pathData = Regex("""<path[^>]*\sd="([^"]+)"""").find(svg)?.groupValues?.get(1)
            ?: return null
        val width = viewBox?.getOrNull(2) ?: 24f
        val height = viewBox?.getOrNull(3) ?: 24f
        return runCatching {
            ImageVector.Builder(
                name = name,
                defaultWidth = 24.dp,
                defaultHeight = 24.dp,
                viewportWidth = width,
                viewportHeight = height,
            ).addPath(
                pathData = PathParser().parsePathString(pathData).toNodes(),
                fill = SolidColor(Color.White),
            ).build()
        }.getOrNull()
    }

    private fun normalize(value: String): String =
        value.lowercase().filter { it.isLetterOrDigit() }
}

@Composable
fun BrandAvatar(
    title: String,
    size: Dp = 40.dp,
    modifier: Modifier = Modifier,
    iconRef: top.talyra42.keycase.core.model.IconRef? = null,
) {
    val context = LocalContext.current
    val vector by produceState<ImageVector?>(initialValue = null, title, iconRef) {
        value = withContext(Dispatchers.IO) {
            if (iconRef?.kind == "pack" && iconRef.value.isNotBlank()) {
                AegisIconPack.vectorFor(context, iconRef.value, title)
                    ?: AegisIconPack.find(context, title)
            } else {
                AegisIconPack.find(context, title)
            }
        }
    }
    val icon = vector
    if (icon == null) {
        LetterAvatar(title = title, size = size, modifier = modifier)
    } else {
        Box(
            modifier = modifier
                .size(size)
                .background(avatarColor(title), RoundedCornerShape(size * 0.32f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(size * 0.62f),
            )
        }
    }
}
