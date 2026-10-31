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
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
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
 * pack.json manifest and SVG icons; AndroidSVG renders the original colors.
 */
object AegisIconPack {
    private const val ASSET = "iconpacks/aegis-simple-icons-v269.zip"

    private var zipBytes: ByteArray? = null
    private var index: Map<String, Entry>? = null
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
            .take(16)
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
    val density = LocalDensity.current
    val targetPx = with(density) { size.toPx() }.toInt()
    val bitmapBucket = when {
        targetPx <= 64 -> 64
        targetPx <= 128 -> 128
        targetPx <= 256 -> 256
        else -> 320
    }
    val initial = remember(title, iconRef, bitmapBucket) {
        val filename = if (iconRef?.kind == "pack" && iconRef.value.isNotBlank()) {
            iconRef.value
        } else {
            AegisIconPack.findFilename(context, title)
        }
        filename?.let { IconBitmapCache.get("svg:$it:$bitmapBucket") }
    }
    var bitmap by remember(title, iconRef, bitmapBucket) { mutableStateOf(initial) }
    var loading by remember(title, iconRef, bitmapBucket) { mutableStateOf(initial == null) }
    LaunchedEffect(title, iconRef, bitmapBucket) {
        if (bitmap == null) {
            bitmap = withContext(Dispatchers.IO) {
                val filename = if (iconRef?.kind == "pack" && iconRef.value.isNotBlank()) {
                    iconRef.value
                } else {
                    AegisIconPack.findFilename(context, title)
                }
                filename?.let { AegisIconPack.bitmapFor(context, it, maxSize = bitmapBucket) }
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
    val density = LocalDensity.current
    val targetPx = with(density) { size.toPx() }.toInt()
    val bucket = when {
        targetPx <= 64 -> 64
        targetPx <= 128 -> 128
        targetPx <= 256 -> 256
        else -> 320
    }
    val cacheKey = "b64:${encoded.hashCode()}:$bucket"
    val cached = remember(encoded, bucket) { IconBitmapCache.get(cacheKey) }
    var image by remember(encoded, bucket) { mutableStateOf(cached) }
    var loading by remember(encoded, bucket) { mutableStateOf(cached == null) }
    LaunchedEffect(encoded, bucket) {
        if (image == null) {
            image = withContext(Dispatchers.IO) {
                runCatching {
                    val bytes = Base64.decode(encoded, Base64.DEFAULT)
                    IconBitmapCache.decodeBase64(
                        encoded.hashCode().toString(),
                        bytes,
                        maxSize = bucket,
                    )
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
