package top.talyra42.keycase.ui.icons

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Base64
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.caverock.androidsvg.SVG
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

    fun findFilename(context: Context, label: String): String? {
        val key = normalize(label)
        if (key.isBlank()) return null
        val entries = ensureIndex(context) ?: return null
        val entry = entries[key]
            ?: entries.entries.firstOrNull { (candidate, _) ->
                candidate.length >= 3 && (key.contains(candidate) || candidate.contains(key))
            }?.value
        return entry?.filename
    }

    /** Warm the index and a handful of avatars before the first list frame. */
    fun prefetch(context: Context, labels: Collection<String>) {
        labels.asSequence()
            .filter { it.isNotBlank() }
            .distinct()
            .take(64)
            .forEach { label ->
                val filename = findFilename(context, label) ?: return@forEach
                bitmapFor(context, filename, maxSize = 112)
            }
    }

    /** Renders the original SVG colors/shapes with AndroidSVG, then caches it. */
    fun bitmapFor(context: Context, filename: String, maxSize: Int = 128): ImageBitmap? {
        if (filename.isBlank()) return null
        val cacheKey = "svg:$filename:$maxSize"
        IconBitmapCache.get(cacheKey)?.let { return it }
        val svgText = readEntry(context, filename) ?: return null
        val rendered = runCatching {
            val svg = SVG.getFromString(svgText)
            val width = svg.documentWidth.takeIf { it > 0f } ?: 24f
            val height = svg.documentHeight.takeIf { it > 0f } ?: 24f
            val scale = minOf(maxSize / width, maxSize / height)
            val outWidth = (width * scale).toInt().coerceAtLeast(1)
            val outHeight = (height * scale).toInt().coerceAtLeast(1)
            val picture = svg.renderToPicture(outWidth, outHeight)
            val bitmap = Bitmap.createBitmap(outWidth, outHeight, Bitmap.Config.ARGB_8888)
            Canvas(bitmap).drawPicture(picture)
            bitmap.asImageBitmap()
        }.getOrNull() ?: return null
        IconBitmapCache.put(cacheKey, rendered)
        return rendered
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
        val width = viewBox?.getOrNull(2) ?: 24f
        val height = viewBox?.getOrNull(3) ?: 24f
        val builder = ImageVector.Builder(
            name = name,
            defaultWidth = 24.dp,
            defaultHeight = 24.dp,
            viewportWidth = width,
            viewportHeight = height,
        )
        var added = false

        // The Aegis pack is based on Simple Icons: a brand-colored circle plus
        // a white glyph. Keep the original fills instead of tinting everything.
        Regex("""<circle\b[^>]*>""").findAll(svg).forEach { match ->
            val tag = match.value
            val cx = attr(tag, "cx")?.toFloatOrNull() ?: return@forEach
            val cy = attr(tag, "cy")?.toFloatOrNull() ?: return@forEach
            val r = attr(tag, "r")?.toFloatOrNull() ?: return@forEach
            val fill = parseFill(attr(tag, "fill")) ?: return@forEach
            val d = "M ${cx - r} $cy A $r $r 0 1 0 ${cx + r} $cy A $r $r 0 1 0 ${cx - r} $cy Z"
            runCatching {
                val nodes = PathParser().parsePathString(d).toNodes()
                builder.addPath(pathData = nodes, fill = SolidColor(fill))
                added = true
            }
        }

        Regex("""<path\b[^>]*>""").findAll(svg).forEach { match ->
            val tag = match.value
            val data = attr(tag, "d") ?: return@forEach
            val fill = parseFill(attr(tag, "fill")) ?: Color.Black
            val transform = attr(tag, "transform")
            val translate = Regex("""translate\(\s*([-\d.]+)[ ,]+([-\d.]+)\s*\)""")
                .find(transform.orEmpty())
            val scale = Regex("""scale\(\s*([-\d.]+)(?:[ ,]+([-\d.]+))?\s*\)""")
                .find(transform.orEmpty())
            runCatching {
                val nodes = PathParser().parsePathString(data).toNodes()
                if (translate != null || scale != null) {
                    builder.addGroup(
                        translationX = translate?.groupValues?.getOrNull(1)?.toFloatOrNull() ?: 0f,
                        translationY = translate?.groupValues?.getOrNull(2)?.toFloatOrNull() ?: 0f,
                        scaleX = scale?.groupValues?.getOrNull(1)?.toFloatOrNull() ?: 1f,
                        scaleY = scale?.groupValues?.getOrNull(2)?.toFloatOrNull()
                            ?: scale?.groupValues?.getOrNull(1)?.toFloatOrNull() ?: 1f,
                        clipPathData = emptyList(),
                    )
                    builder.addPath(pathData = nodes, fill = SolidColor(fill))
                    builder.clearGroup()
                } else {
                    builder.addPath(pathData = nodes, fill = SolidColor(fill))
                }
                added = true
            }
        }
        return if (added) builder.build() else null
    }

    private fun attr(tag: String, name: String): String? {
        val match = Regex("""\b$name="([^"]*)"""").find(tag) ?: return null
        return match.groupValues[1]
    }

    private fun parseFill(value: String?): Color? {
        if (value.isNullOrBlank()) return null
        if (value.equals("none", ignoreCase = true)) return null
        if (value.equals("white", ignoreCase = true)) return Color.White
        if (value.equals("black", ignoreCase = true)) return Color.Black
        if (value.startsWith("#")) {
            val hex = value.removePrefix("#")
            return runCatching {
                when (hex.length) {
                    6 -> Color((0xFF000000L or hex.toLong(16)).toInt())
                    8 -> Color(hex.toLong(16).toInt())
                    else -> null
                }
            }.getOrNull()
        }
        return null
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
    if (iconRef?.kind == "custom" && iconRef.value.isNotBlank()) {
        CustomIconAvatar(title, iconRef.value, size, modifier)
        return
    }
    val context = LocalContext.current
    val initial = remember(title, iconRef) {
        val filename = if (iconRef?.kind == "pack" && iconRef.value.isNotBlank()) {
            iconRef.value
        } else {
            AegisIconPack.findFilename(context, title)
        }
        filename?.let { IconBitmapCache.get("svg:$it:112") }
    }
    var bitmap by remember(title, iconRef) { mutableStateOf(initial) }
    var loading by remember(title, iconRef) { mutableStateOf(initial == null) }
    LaunchedEffect(title, iconRef) {
        if (bitmap == null) {
            bitmap = withContext(Dispatchers.IO) {
                val filename = if (iconRef?.kind == "pack" && iconRef.value.isNotBlank()) {
                    iconRef.value
                } else {
                    AegisIconPack.findFilename(context, title)
                }
                filename?.let { AegisIconPack.bitmapFor(context, it, maxSize = 112) }
            }
        }
        loading = false
    }
    if (loading) {
        Box(
            modifier = modifier
                .size(size)
                .background(
                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f),
                    RoundedCornerShape(size * 0.32f),
                ),
        )
        return
    }
    if (bitmap == null) {
        LetterAvatar(title = title, size = size, modifier = modifier)
    } else {
        Image(
            bitmap = bitmap!!,
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = modifier.size(size),
        )
    }
}

@Composable
private fun CustomIconAvatar(
    title: String,
    encoded: String,
    size: Dp,
    modifier: Modifier,
) {
    val cached = remember(encoded) { IconBitmapCache.get("b64:${encoded.hashCode()}:96") }
    var image by remember(encoded) { mutableStateOf(cached) }
    var loading by remember(encoded) { mutableStateOf(cached == null) }
    LaunchedEffect(encoded) {
        if (image == null) {
            image = withContext(Dispatchers.IO) {
                runCatching {
                    val bytes = Base64.decode(encoded, Base64.DEFAULT)
                    IconBitmapCache.decodeBase64(encoded.hashCode().toString(), bytes)
                }.getOrNull()
            }
        }
        loading = false
    }
    if (loading) {
        Box(
            modifier = modifier
                .size(size)
                .background(
                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f),
                    RoundedCornerShape(size * 0.32f),
                ),
        )
    } else if (image == null) {
        LetterAvatar(title = title, size = size, modifier = modifier)
    } else {
        Image(
            bitmap = image!!,
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = modifier
                .size(size)
                .clip(RoundedCornerShape(size * 0.32f)),
        )
    }
}
