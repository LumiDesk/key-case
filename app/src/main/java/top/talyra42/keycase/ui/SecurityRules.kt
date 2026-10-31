package top.talyra42.keycase.ui

import top.talyra42.keycase.core.model.VaultItem

data class SecurityIssue(
    val item: VaultItem,
    val reason: String,
)

private val COMMON_PASSWORDS = setOf(
    "123456",
    "password",
    "12345678",
    "qwerty",
    "111111",
    "abc123",
)

/**
 * Single source of truth for the home "needs attention" counter and the
 * security center list.
 */
fun securityIssues(items: List<VaultItem>): List<SecurityIssue> {
    val reused = items.groupBy { it.password }
        .filterValues { it.size > 1 }
        .keys
    return items.mapNotNull { item ->
        val password = item.password
        val reason = when {
            password.isBlank() -> "没有密码"
            password.length < 8 -> "密码太短"
            password.all(Char::isDigit) -> "只有数字"
            password.lowercase() in COMMON_PASSWORDS -> "常见弱密码"
            password in reused -> "密码重复"
            else -> null
        }
        reason?.let { SecurityIssue(item, it) }
    }
}

fun passwordIssueCount(items: List<VaultItem>): Int = securityIssues(items).size
