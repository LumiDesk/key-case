package top.talyra42.keycase.core.otp

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import top.talyra42.keycase.core.model.HashAlgorithm
import top.talyra42.keycase.core.model.OtpType
import top.talyra42.keycase.core.model.TotpSecret

class OtpTest {
    private val sha1Secret = "12345678901234567890".toByteArray()
    private val sha256Secret = "12345678901234567890123456789012".toByteArray()
    private val sha512Secret =
        "1234567890123456789012345678901234567890123456789012345678901234".toByteArray()

    @Test
    fun rfc6238Sha1Vector() {
        assertEquals("94287082", Otp.generate(sha1Secret, 59_000L, digits = 8, algorithm = HashAlgorithm.SHA1))
    }

    @Test
    fun rfc6238Sha256Vector() {
        assertEquals("46119246", Otp.generate(sha256Secret, 59_000L, digits = 8, algorithm = HashAlgorithm.SHA256))
    }

    @Test
    fun rfc6238Sha512Vector() {
        assertEquals("90693936", Otp.generate(sha512Secret, 59_000L, digits = 8, algorithm = HashAlgorithm.SHA512))
    }

    @Test
    fun rfc4226HotpVector() {
        assertEquals("755224", Otp.hotp(sha1Secret, 0))
        assertEquals("287082", Otp.hotp(sha1Secret, 1))
        assertEquals("359152", Otp.hotp(sha1Secret, 2))
    }

    @Test
    fun base32RoundTrip() {
        val encoded = Base32.encode(sha1Secret)
        assertEquals("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", encoded)
        assertEquals(sha1Secret.toList(), Base32.decode(encoded).toList())
        assertEquals(sha1Secret.toList(), Base32.decode(encoded.lowercase()).toList())
    }

    @Test
    fun base32RejectsInvalidCharacters() {
        assertThrows(IllegalArgumentException::class.java) {
            Base32.decode("JBSWY3DPEHPK3PX!")
        }
    }

    @Test
    fun parsesTotpUri() {
        val parsed = OtpauthParser.parse(
            "otpauth://totp/GitHub:lin.dev?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA1&digits=6&period=30",
        )

        assertEquals(OtpType.TOTP, parsed.type)
        assertEquals("GitHub", parsed.issuer)
        assertEquals("lin.dev", parsed.account)
        assertEquals("JBSWY3DPEHPK3PXP", parsed.secret)
        assertEquals(HashAlgorithm.SHA1, parsed.algorithm)
        assertEquals(6, parsed.digits)
        assertEquals(30, parsed.period)
    }

    @Test
    fun totpSecretGeneratesCode() {
        val secret = TotpSecret(secret = "JBSWY3DPEHPK3PXP")
        assertEquals(6, secret.codeAt(59_000L).length)
        assertEquals(secret.codeAt(59_000L), secret.codeAt(60_000L - 1))
    }
}
