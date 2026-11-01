package top.talyra42.keycase.ui

import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import top.talyra42.keycase.data.AppSettings
import top.talyra42.keycase.ui.theme.KeyCaseTheme

@RunWith(AndroidJUnit4::class)
class CreateVaultScreenTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun createButtonInvokesCallback() {
        var captured: Pair<String, String>? = null

        compose.setContent {
            KeyCaseTheme(AppSettings()) {
                CreateVaultScreen(
                    busy = false,
                    error = null,
                    onCreate = { password, confirm -> captured = password to confirm },
                )
            }
        }

        compose.onNode(hasText("创建保险库") or hasText("Create vault")).performClick()

        assertEquals("", captured?.first)
        assertEquals("", captured?.second)
    }
}
