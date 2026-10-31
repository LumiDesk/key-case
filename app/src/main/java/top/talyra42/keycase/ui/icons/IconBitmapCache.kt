package top.talyra42.keycase.ui.icons

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import java.io.File

/** Small memory cache for icon previews; avoids re-decoding while scrolling. */
object IconBitmapCache {
    private val cache = LruCache<String, ImageBitmap>(160)

    fun get(key: String): ImageBitmap? = synchronized(cache) { cache.get(key) }

    fun decodeFile(file: File, maxSize: Int = 96): ImageBitmap? {
        val key = "file:${file.absolutePath}:$maxSize"
        synchronized(cache) { cache.get(key) }?.let { return it }
        val bitmap = decodeScaled(file, maxSize) ?: return null
        val image = bitmap.asImageBitmap()
        synchronized(cache) { cache.put(key, image) }
        return image
    }

    fun decodeBase64(key: String, bytes: ByteArray, maxSize: Int = 96): ImageBitmap? {
        val cacheKey = "b64:$key:$maxSize"
        synchronized(cache) { cache.get(cacheKey) }?.let { return it }
        val bitmap = decodeScaled(bytes, maxSize) ?: return null
        val image = bitmap.asImageBitmap()
        synchronized(cache) { cache.put(cacheKey, image) }
        return image
    }

    private fun decodeScaled(file: File, maxSize: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, maxSize)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeFile(file.absolutePath, options)
    }

    private fun decodeScaled(bytes: ByteArray, maxSize: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, maxSize)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    }

    private fun sampleSize(width: Int, height: Int, maxSize: Int): Int {
        var sample = 1
        while (width / (sample * 2) >= maxSize && height / (sample * 2) >= maxSize) {
            sample *= 2
        }
        return sample
    }
}
