package top.talyra42.keycase.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL

/**
 * Manual update check against GitHub Releases.
 *
 * KeyCase makes no background network calls: this is only invoked when the
 * user taps "Check for updates" in Settings → About.
 */
object UpdateChecker {
    data class Update(
        val latestVersion: String,
        val releaseUrl: String,
        val available: Boolean,
    )

    suspend fun check(currentVersion: String): Update = withContext(Dispatchers.IO) {
        val connection = (URL("https://api.github.com/repos/LumiDesk/key-case/releases/latest")
            .openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 8_000
            readTimeout = 8_000
            setRequestProperty("Accept", "application/vnd.github+json")
            setRequestProperty("User-Agent", "KeyCase-Android")
        }
        try {
            if (connection.responseCode != 200) {
                error("GitHub returned ${connection.responseCode}")
            }
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val json = Json.parseToJsonElement(body).jsonObject
            val tag = json["tag_name"]?.jsonPrimitive?.content
                ?: error("Missing tag_name")
            val releaseUrl = json["html_url"]?.jsonPrimitive?.content
                ?: "https://github.com/LumiDesk/key-case/releases/latest"
            val latest = tag.removePrefix("v").trim()
            Update(
                latestVersion = latest,
                releaseUrl = releaseUrl,
                available = isNewer(latest, currentVersion),
            )
        } finally {
            connection.disconnect()
        }
    }

    fun isNewer(latest: String, current: String): Boolean {
        val a = parseVersion(latest) ?: return false
        val b = parseVersion(current) ?: return false
        for (index in 0 until maxOf(a.size, b.size)) {
            val left = a.getOrElse(index) { 0 }
            val right = b.getOrElse(index) { 0 }
            if (left != right) return left > right
        }
        return false
    }

    private fun parseVersion(value: String): List<Int>? {
        val core = value.trim().removePrefix("v").substringBefore('-').substringBefore('+')
        val parts = core.split('.')
        if (parts.isEmpty()) return null
        val numbers = parts.mapNotNull { it.toIntOrNull() }
        return if (numbers.size == parts.size) numbers else null
    }
}
