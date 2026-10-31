package top.talyra42.keycase.ui

/**
 * Formats a TOTP code with the user's preferred group size.
 *
 * AUTO follows the code length: 6 digits -> 3+3, 8 digits -> 4+4.
 * The dots used while codes are hidden go through the same formatter so the
 * placeholder has the same shape as the real code.
 */
fun formatTokenCode(
    code: String,
    digits: Int,
    grouping: CodeGrouping,
): String {
    if (code.isBlank()) return code
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
): String = formatTokenCode("•".repeat(digits.coerceAtLeast(6)), digits, grouping)
