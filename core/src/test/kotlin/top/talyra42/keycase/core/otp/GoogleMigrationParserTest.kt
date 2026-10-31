package top.talyra42.keycase.core.otp

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import top.talyra42.keycase.core.model.HashAlgorithm
import top.talyra42.keycase.core.model.OtpType
import java.io.ByteArrayOutputStream
import java.util.Base64

class GoogleMigrationParserTest {
    @Test
    fun parsesTotpAndHotpEntries() {
        val first = parameters(
            secret = "12345678901234567890".toByteArray(),
            name = "alice@example.com",
            issuer = "Example",
            algorithm = 2,
            digits = 2,
            type = 2,
        )
        val second = parameters(
            secret = "abcdefghijklmnop".toByteArray(),
            name = "bob@example.com",
            issuer = "",
            algorithm = 1,
            digits = 1,
            type = 1,
            counter = 7,
        )
        val payload = concat(fieldBytes(1, first), fieldBytes(1, second), fieldVarint(2, 1))
        val uri = "otpauth-migration://offline?data=" +
            Base64.getUrlEncoder().withoutPadding().encodeToString(payload)

        val parsed = GoogleMigrationParser.parse(uri)

        assertEquals(2, parsed.size)
        assertEquals("Example", parsed[0].issuer)
        assertEquals("alice@example.com", parsed[0].account)
        assertEquals(HashAlgorithm.SHA256, parsed[0].algorithm)
        assertEquals(8, parsed[0].digits)
        assertEquals(OtpType.TOTP, parsed[0].type)
        assertEquals("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", parsed[0].secret)
        assertEquals(OtpType.HOTP, parsed[1].type)
        assertEquals(7L, parsed[1].counter)
        assertEquals(HashAlgorithm.SHA1, parsed[1].algorithm)
    }

    @Test
    fun rejectsWrongScheme() {
        assertThrows(IllegalArgumentException::class.java) {
            GoogleMigrationParser.parse("otpauth://totp/x?secret=JBSWY3DPEHPK3PXP")
        }
    }

    @Test
    fun rejectsEmptyPayload() {
        val uri = "otpauth-migration://offline?data=" +
            Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(0))
        assertThrows(IllegalArgumentException::class.java) {
            GoogleMigrationParser.parse(uri)
        }
    }

    private fun parameters(
        secret: ByteArray,
        name: String,
        issuer: String,
        algorithm: Int,
        digits: Int,
        type: Int,
        counter: Long = 0,
    ): ByteArray = concat(
        fieldBytes(1, secret),
        fieldBytes(2, name.toByteArray()),
        fieldBytes(3, issuer.toByteArray()),
        fieldVarint(4, algorithm.toLong()),
        fieldVarint(5, digits.toLong()),
        fieldVarint(6, type.toLong()),
        fieldVarint(7, counter),
    )

    private fun fieldBytes(field: Int, value: ByteArray): ByteArray =
        concat(varint(((field shl 3) or 2).toLong()), varint(value.size.toLong()), value)

    private fun fieldVarint(field: Int, value: Long): ByteArray =
        concat(varint(((field shl 3) or 0).toLong()), varint(value))

    private fun varint(value: Long): ByteArray {
        var remaining = value
        val out = ByteArrayOutputStream()
        while (true) {
            if (remaining < 0x80) {
                out.write(remaining.toInt())
                return out.toByteArray()
            }
            out.write(((remaining and 0x7F) or 0x80).toInt())
            remaining = remaining ushr 7
        }
    }

    private fun concat(vararg parts: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        parts.forEach(out::write)
        return out.toByteArray()
    }
}
