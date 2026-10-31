package top.talyra42.keycase.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AccentHexTest {
    @Test
    fun parsesSixDigitHex() {
        assertEquals(0xFF2563EB.toInt(), parseAccentHex("#2563EB"))
        assertEquals(0xFF2563EB.toInt(), parseAccentHex("2563eb"))
    }

    @Test
    fun parsesEightDigitHex() {
        assertEquals(0x80112233.toInt(), parseAccentHex("#80112233"))
    }

    @Test
    fun rejectsInvalidValues() {
        assertNull(parseAccentHex("#12345"))
        assertNull(parseAccentHex("not-a-color"))
        assertNull(parseAccentHex(""))
    }
}
