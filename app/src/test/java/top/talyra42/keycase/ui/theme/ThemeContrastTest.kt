package top.talyra42.keycase.ui.theme

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Test

class ThemeContrastTest {
    private val ink = Color(0xFF111827)

    @Test
    fun darkInkIsUsedForLightAccents() {
        assertEquals(ink, onAccent(Color(0xFF059669))) // green
        assertEquals(ink, onAccent(Color(0xFFD97706))) // amber
        assertEquals(ink, onAccent(Color.White))
    }

    @Test
    fun whiteIsUsedForDarkAccents() {
        assertEquals(Color.White, onAccent(Color(0xFF2563EB))) // blue
        assertEquals(Color.White, onAccent(Color(0xFF0F766E))) // teal
        assertEquals(Color.White, onAccent(Color(0xFFE11D48))) // rose
    }
}
