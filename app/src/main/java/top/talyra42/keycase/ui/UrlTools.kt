package top.talyra42.keycase.ui

import java.net.URI

/**
 * Returns a browser-safe http(s) URL, prefixing a missing scheme with https.
 * Returns null for other schemes or malformed input so the UI can hide "open".
 */
fun safeHttpUrl(raw: String): String? {
    val trimmed = raw.trim()
    if (trimmed.isEmpty()) return null
    val hasOtherScheme = Regex("^[a-zA-Z][a-zA-Z0-9+.-]*:")
        .find(trimmed)
        ?.let { !it.value.equals("http:", true) && !it.value.equals("https:", true) }
        ?: false
    if (hasOtherScheme) return null
    val withScheme = if (
        trimmed.startsWith("http://", ignoreCase = true) ||
        trimmed.startsWith("https://", ignoreCase = true)
    ) {
        trimmed
    } else {
        "https://$trimmed"
    }
    return runCatching { URI(withScheme) }.getOrNull()
        ?.takeIf {
            (it.scheme.equals("http", ignoreCase = true) ||
                it.scheme.equals("https", ignoreCase = true)) &&
                !it.host.isNullOrBlank()
        }
        ?.toString()
}
