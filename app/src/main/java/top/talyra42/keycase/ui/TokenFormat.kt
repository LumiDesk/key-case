package top.talyra42.keycase.ui

import top.talyra42.keycase.core.model.OtpType
import top.talyra42.keycase.data.CodeGrouping

/**
 * Formats a TOTP code with the user's preferred group size.
 *
 * AUTO follows the code length: 6 digits -> 3+3, 8 digits -> 4+4.
 * The dots used while codes are hidden go through the same formatter so the
 * placeholder has the same shape as the real code. Steam codes are always a
 * five-character word and are never grouped.
 */
fun formatTokenCode(
    code: String,
    digits: Int,
    grouping: CodeGrouping,
    type: OtpType = OtpType.TOTP,
): String {
    if (code.isBlank() || type == OtpType.STEAM) return code
    val size = when (grouping) {
        CodeGrouping.AUTO -> if (digits >= 8) 4 else 3
        CodeGrouping.THREE -> 3
        CodeGrouping.FOUR -> 4
        CodeGrouping.NONE -> 0
    }
    if (size <= 0 || code.length <= size) return code
    return code.chunked(size).joinToString(" ")
}

fun hiddenTokenCode(
    digits: Int,
    grouping: CodeGrouping,
    type: OtpType = OtpType.TOTP,
): String {
    val count = if (type == OtpType.STEAM) 5 else digits.coerceAtLeast(6)
    return formatTokenCode("•".repeat(count), count, grouping, type)
}
