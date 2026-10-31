package top.talyra42.keycase.ui

import org.junit.Assert.assertEquals
import org.junit.Test
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.VaultItem

class PasswordIssueCountTest {
    private fun item(id: String, password: String) = VaultItem(
        id = id,
        kind = ItemKind.LOGIN,
        title = id,
        password = password,
    )

    @Test
    fun flagsShortAndCommonAndReusedPasswords() {
        val items = listOf(
            item("good", "correct horse battery staple"),
            item("short", "abc"),
            item("common", "123456"),
            item("reuse-1", "same-password-2026"),
            item("reuse-2", "same-password-2026"),
        )

        // short + common + both reused entries
        assertEquals(4, passwordIssueCount(items))
    }

    @Test
    fun cleanVaultHasNoIssues() {
        val items = listOf(
            item("a", "a-long-and-unique-password"),
            item("b", "another-long-and-unique-password"),
        )

        assertEquals(0, passwordIssueCount(items))
    }
}
