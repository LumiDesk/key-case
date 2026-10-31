package top.talyra42.keycase.ui

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.assertIsDisplayed
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
                    groups = emptyList(),
                    onBack = {},
                    onSave = { _, _ -> },
                )
            }
        }

        compose.onNodeWithText("新建密码").assertIsDisplayed()
        compose.onNodeWithText("保存密码").assertIsDisplayed()
    }
}
