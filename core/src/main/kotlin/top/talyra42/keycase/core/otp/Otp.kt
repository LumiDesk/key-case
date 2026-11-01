package top.talyra42.keycase.core.otp

import top.talyra42.keycase.core.model.HashAlgorithm
import top.talyra42.keycase.core.model.OtpType
import top.talyra42.keycase.core.model.TotpSecret
import java.io.ByteArrayOutputStream
import java.net.URI
import java.net.URLDecoder
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

object Base32 {
    private const val ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    fun encode(data: ByteArray): String {
        if (data.isEmpty()) return ""
        val out = StringBuilder((data.size * 8 + 4) / 5)
        var buffer = 0
        var bits = 0
        for (byte in data) {
            buffer = (buffer shl 8) or (byte.toInt() and 0xFF)
            bits += 8
            while (bits >= 5) {
                out.append(ALPHABET[(buffer shr (bits - 5)) and 31])
                bits -= 5
            }
        }
        if (bits > 0) {
            out.append(ALPHABET[(buffer shl (5 - bits)) and 31])
        }
        return out.toString()
    }

    fun decode(input: String): ByteArray {
        val clean = input
            .trim()
            .uppercase()
            .replace(" ", "")
            .replace("-", "")
            .trimEnd('=')
        if (clean.isEmpty()) throw IllegalArgumentException("Base32 secret is empty")

        val out = ByteArrayOutputStream(clean.length * 5 / 8)
        var buffer = 0
        var bits = 0
        for (char in clean) {
            val value = ALPHABET.indexOf(char)
            if (value < 0) throw IllegalArgumentException("Invalid Base32 character: $char")
            buffer = (buffer shl 5) or value
            bits += 5
            if (bits >= 8) {
                out.write((buffer shr (bits - 8)) and 0xFF)
                bits -= 8
                buffer = buffer and ((1 shl bits) - 1)
            }
        }
        if (bits > 0 && buffer != 0) {
            throw IllegalArgumentException("Invalid Base32 padding")
        }
        return out.toByteArray()
    }
}

object Otp {
    private const val STEAM_ALPHABET = "23456789BCDFGHJKMNPQRTVWXY"

    fun generate(
        secret: ByteArray,
        timeMillis: Long,
        period: Int = 30,
        digits: Int = 6,
        algorithm: HashAlgorithm = HashAlgorithm.SHA1,
    ): String {
        require(period > 0) { "period must be positive" }
        require(timeMillis >= 0) { "time must be positive" }
        val counter = timeMillis / 1000L / period
        return hotp(secret, counter, digits, algorithm)
    }

    fun hotp(
        secret: ByteArray,
        counter: Long,
        digits: Int = 6,
        algorithm: HashAlgorithm = HashAlgorithm.SHA1,
    ): String {
        require(secret.isNotEmpty()) { "secret must not be empty" }
        require(digits in 1..8) { "digits must be between 1 and 8" }
        require(counter >= 0) { "counter must be positive" }

        val hash = hmac(secret, counter, algorithm)
        val binary = dynamicTruncate(hash)
        val modulo = when (digits) {
            1 -> 10L
            2 -> 100L
            3 -> 1_000L
            4 -> 10_000L
            5 -> 100_000L
            6 -> 1_000_000L
            7 -> 10_000_000L
            else -> 100_000_000L
        }
        return (binary.toLong() % modulo).toString().padStart(digits, '0')
    }

    fun steam(secret: ByteArray, timeMillis: Long, period: Int = 30): String {
        require(period > 0) { "period must be positive" }
        val counter = timeMillis / 1000L / period
        val hash = hmac(secret, counter, HashAlgorithm.SHA1)
        var binary = dynamicTruncate(hash)
        val out = StringBuilder(5)
        repeat(5) {
            out.append(STEAM_ALPHABET[binary % STEAM_ALPHABET.length])
            binary /= STEAM_ALPHABET.length
        }
        return out.toString()
    }

    private fun hmac(secret: ByteArray, counter: Long, algorithm: HashAlgorithm): ByteArray {
        val macAlgorithm = when (algorithm) {
            HashAlgorithm.SHA1 -> "HmacSHA1"
            HashAlgorithm.SHA256 -> "HmacSHA256"
            HashAlgorithm.SHA512 -> "HmacSHA512"
        }
        val mac = Mac.getInstance(macAlgorithm)
        mac.init(SecretKeySpec(secret, macAlgorithm))
        val message = ByteBuffer.allocate(8).putLong(counter).array()
        return mac.doFinal(message)
    }

    private fun dynamicTruncate(hash: ByteArray): Int {
        val offset = hash.last().toInt() and 0x0F
        return ((hash[offset].toInt() and 0x7F) shl 24) or
            ((hash[offset + 1].toInt() and 0xFF) shl 16) or
            ((hash[offset + 2].toInt() and 0xFF) shl 8) or
            (hash[offset + 3].toInt() and 0xFF)
    }
}

fun TotpSecret.codeAt(timeMillis: Long): String {
    val key = Base32.decode(secret)
    return when (type) {
        OtpType.TOTP -> Otp.generate(key, timeMillis, period, digits, algorithm)
        OtpType.HOTP -> Otp.hotp(key, counter, digits, algorithm)
        OtpType.STEAM -> Otp.steam(key, timeMillis, period)
    }
}

/**
 * The code that will be valid next. TOTP/Steam move to the next time window;
 * HOTP moves to the next counter value without mutating the stored secret.
 */
fun TotpSecret.nextCode(timeMillis: Long): String {
    val key = Base32.decode(secret)
    return when (type) {
        OtpType.TOTP -> Otp.generate(key, timeMillis + period * 1000L, period, digits, algorithm)
        OtpType.HOTP -> Otp.hotp(key, counter + 1, digits, algorithm)
        OtpType.STEAM -> Otp.steam(key, timeMillis + period * 1000L, period)
    }
}

fun TotpSecret.withNextCounter(): TotpSecret = copy(counter = counter + 1)

data class ParsedOtp(
    val type: OtpType,
    val issuer: String,
    val account: String,
    val secret: String,
    val algorithm: HashAlgorithm,
    val digits: Int,
    val period: Int,
    val counter: Long,
)

object OtpauthParser {
    fun parse(uriString: String): ParsedOtp {
        val uri = try {
            URI(uriString)
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid otpauth URI", e)
        }
        if (!uri.scheme.equals("otpauth", ignoreCase = true)) {
            throw IllegalArgumentException("Unsupported URI scheme: ${uri.scheme}")
        }

        val type = when (uri.host?.lowercase()) {
            "totp" -> OtpType.TOTP
            "hotp" -> OtpType.HOTP
            "steam" -> OtpType.STEAM
            else -> throw IllegalArgumentException("Unsupported OTP type: ${uri.host}")
        }

        val params = parseQuery(uri.rawQuery)
        val encodedSecret = params["secret"]
            ?: throw IllegalArgumentException("Missing secret")
        // Validate now so a bad QR code fails at import time, not at fill time.
        Base32.decode(encodedSecret)

        val label = URLDecoder.decode(uri.rawPath.orEmpty().removePrefix("/"), StandardCharsets.UTF_8)
        val labelIssuer = if (label.contains(':')) label.substringBefore(':') else ""
        val account = if (label.contains(':')) label.substringAfter(':') else label
        val issuer = params["issuer"].orEmpty().ifBlank { labelIssuer }

        val algorithm = when (params["algorithm"]?.uppercase()) {
            null, "", "SHA1" -> HashAlgorithm.SHA1
            "SHA256" -> HashAlgorithm.SHA256
            "SHA512" -> HashAlgorithm.SHA512
            else -> throw IllegalArgumentException("Unsupported algorithm: ${params["algorithm"]}")
        }
        val digits = if (type == OtpType.STEAM) {
            5
        } else {
            params["digits"]?.toIntOrNull() ?: 6
        }
        if (digits !in 1..8) throw IllegalArgumentException("Invalid digits: $digits")
        val period = params["period"]?.toIntOrNull() ?: 30
        if (period !in 1..300) throw IllegalArgumentException("Invalid period: $period")
        val counter = params["counter"]?.toLongOrNull() ?: 0L
        if (type == OtpType.HOTP && counter < 0) {
            throw IllegalArgumentException("Invalid HOTP counter: $counter")
        }

        return ParsedOtp(
            type = type,
            issuer = issuer,
            account = account,
            secret = encodedSecret,
            algorithm = algorithm,
            digits = digits,
            period = period,
            counter = counter,
        )
    }

    private fun parseQuery(rawQuery: String?): Map<String, String> {
        if (rawQuery.isNullOrBlank()) return emptyMap()
        return rawQuery.split('&')
            .filter { it.isNotBlank() }
            .associate { part ->
                val index = part.indexOf('=')
                if (index < 0) {
                    URLDecoder.decode(part, StandardCharsets.UTF_8) to ""
                } else {
                    URLDecoder.decode(part.substring(0, index), StandardCharsets.UTF_8) to
                        URLDecoder.decode(part.substring(index + 1), StandardCharsets.UTF_8)
                }
            }
    }
}
