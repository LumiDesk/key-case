package top.talyra42.keycase.ui

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.ZoneId

class DateFormattingTest {
    @Test
    fun utcInstantIsRenderedInTheDeviceZone() {
        assertEquals(
            "2026-10-31 22:00",
            formatVaultTimestamp(
                "2026-10-31T14:00:00Z",
                "yyyy-MM-dd HH:mm",
                ZoneId.of("Asia/Shanghai"),
            ),
        )
        assertEquals(
            "2026-11-01 00:30",
            formatVaultTimestamp(
                "2026-10-31T16:30:00Z",
                "yyyy-MM-dd HH:mm",
                ZoneId.of("Asia/Shanghai"),
            ),
        )
    }

    @Test
    fun malformedTimestampFallsBackWithoutCrashing() {
        assertEquals(
            "not-a-timestamp",
            formatVaultTimestamp("not-a-timestamp", "yyyy-MM-dd", ZoneId.of("UTC")),
        )
    }
}
