package top.talyra42.keycase.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import top.talyra42.keycase.ui.theme.KeyCaseTheme

@RunWith(AndroidJUnit4::class)
class PasswordEditorSheetTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun newPasswordSheetRenders() {
        compose.setContent {
            KeyCaseTheme(AppSettings()) {
                PasswordEditorScreen(
                    item = null,
                    onBack = {},
                    onSave = { _ -> },
                )
            }
        }

        compose.onNode(hasText("新建密码") or hasText("New password")).assertIsDisplayed()
        compose.onNode(hasText("保存密码") or hasText("Save password")).assertIsDisplayed()
    }
}
