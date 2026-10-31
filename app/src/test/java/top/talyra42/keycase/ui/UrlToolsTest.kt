package top.talyra42.keycase.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class UrlToolsTest {
    @Test
    fun keepsExplicitHttpUrls() {
        assertEquals("https://github.com", safeHttpUrl("https://github.com"))
        assertEquals("http://example.com/path", safeHttpUrl("http://example.com/path"))
    }

    @Test
    fun addsHttpsToBareHosts() {
        assertEquals("https://github.com", safeHttpUrl("github.com"))
    }

    @Test
    fun rejectsUnsafeOrBrokenUrls() {
        assertNull(safeHttpUrl("javascript:alert(1)"))
        assertNull(safeHttpUrl("ftp://example.com"))
        assertNull(safeHttpUrl(""))
        assertNull(safeHttpUrl("not a url"))
    }
}
