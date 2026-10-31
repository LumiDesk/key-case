package top.talyra42.keycase.ui

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Vault timestamps are stored as UTC ISO-8601 instants. UI must never slice the
 * raw string: doing so shows UTC time to a user who lives in another zone.
 */
internal fun formatVaultTimestamp(
    iso: String,
    pattern: String,
    zoneId: ZoneId = ZoneId.systemDefault(),
): String = runCatching {
    DateTimeFormatter.ofPattern(pattern, Locale.getDefault())
        .withZone(zoneId)
        .format(Instant.parse(iso))
}.getOrDefault(iso.take(16).replace('T', ' '))

fun formatUpdatedAt(iso: String): String =
    formatVaultTimestamp(iso, "yyyy-MM-dd HH:mm")

fun formatDeletedAt(iso: String): String =
    formatVaultTimestamp(iso, "yyyy-MM-dd")
