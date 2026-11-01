package top.talyra42.keycase.ui

import org.junit.Assert.assertEquals
import org.junit.Test
import top.talyra42.keycase.core.model.OtpType
import top.talyra42.keycase.data.CodeGrouping

class TokenFormatTest {
    @Test
    fun autoUsesThreeForSixDigits() {
        assertEquals("123 456", formatTokenCode("123456", 6, CodeGrouping.AUTO))
    }

    @Test
    fun autoUsesFourForEightDigits() {
        assertEquals("1234 5678", formatTokenCode("12345678", 8, CodeGrouping.AUTO))
    }

    @Test
    fun explicitGroupingOverridesLength() {
        assertEquals("123 456", formatTokenCode("123456", 6, CodeGrouping.THREE))
        assertEquals("1234 56", formatTokenCode("123456", 6, CodeGrouping.FOUR))
        assertEquals("12345678", formatTokenCode("12345678", 8, CodeGrouping.NONE))
    }

    @Test
    fun hiddenMaskKeepsGroupShape() {
        assertEquals("••• •••", hiddenTokenCode(6, CodeGrouping.AUTO))
        assertEquals("•••• ••••", hiddenTokenCode(8, CodeGrouping.AUTO))
    }

    @Test
    fun steamCodeIsNeverGrouped() {
        assertEquals("K5K5K", formatTokenCode("K5K5K", 5, CodeGrouping.AUTO, OtpType.STEAM))
        assertEquals("•••••", hiddenTokenCode(5, CodeGrouping.AUTO, OtpType.STEAM))
    }
}
