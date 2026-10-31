package top.talyra42.keycase.data

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdateCheckerTest {
    @Test
    fun newerMinorVersionIsDetected() {
        assertTrue(UpdateChecker.isNewer("0.1.1", "0.1.0"))
        assertTrue(UpdateChecker.isNewer("0.2.0", "0.1.9"))
    }

    @Test
    fun sameOrOlderVersionIsNotNewer() {
        assertFalse(UpdateChecker.isNewer("0.1.1", "0.1.1"))
        assertFalse(UpdateChecker.isNewer("0.1.0", "0.1.1"))
    }

    @Test
    fun leadingVAndSuffixAreIgnored() {
        assertTrue(UpdateChecker.isNewer("v0.2.0", "0.1.9"))
        assertFalse(UpdateChecker.isNewer("v0.1.1-beta", "0.1.1"))
    }
}
