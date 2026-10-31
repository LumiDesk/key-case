package top.talyra42.keycase.core.otp

import top.talyra42.keycase.core.model.HashAlgorithm
import top.talyra42.keycase.core.model.OtpType
import java.io.ByteArrayOutputStream
import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Base64

/**
 * Parser for the protobuf payload used by Google Authenticator's
 * "Export accounts" QR code.
 *
 * URI: otpauth-migration://offline?data=<base64url(protobuf)>
 */
object GoogleMigrationParser {
    fun parse(uriString: String): List<ParsedOtp> {
        val uri = try {
            URI(uriString)
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid migration URI", e)
        }
        if (!uri.scheme.equals("otpauth-migration", ignoreCase = true)) {
            throw IllegalArgumentException("Unsupported migration scheme: ${uri.scheme}")
        }
        val data = queryParam(uri.rawQuery, "data")
            ?: throw IllegalArgumentException("Missing migration data")

        val bytes = decodeBase64(data)
        val entries = mutableListOf<ParsedOtp>()
        val reader = ProtoReader(bytes)
        while (reader.hasMore()) {
            val tag = reader.varint().toInt()
            val field = tag ushr 3
            val wire = tag and 0x7
            if (field == 1 && wire == 2) {
                entries += parseParameters(reader.lengthDelimited())
            } else {
                reader.skip(wire)
            }
        }
        if (entries.isEmpty()) {
            throw IllegalArgumentException("Migration payload contains no accounts")
        }
        return entries
    }

    private fun parseParameters(data: ByteArray): ParsedOtp {
        var secret: ByteArray? = null
        var name = ""
        var issuer = ""
        var algorithm = 0
        var digits = 0
        var type = 0
        var counter = 0L

        val reader = ProtoReader(data)
        while (reader.hasMore()) {
            val tag = reader.varint().toInt()
            val field = tag ushr 3
            val wire = tag and 0x7
            when {
                field == 1 && wire == 2 -> secret = reader.lengthDelimited()
                field == 2 && wire == 2 -> name = reader.lengthDelimited().toString(StandardCharsets.UTF_8)
                field == 3 && wire == 2 -> issuer = reader.lengthDelimited().toString(StandardCharsets.UTF_8)
                field == 4 && wire == 0 -> algorithm = reader.varint().toInt()
                field == 5 && wire == 0 -> digits = reader.varint().toInt()
                field == 6 && wire == 0 -> type = reader.varint().toInt()
                field == 7 && wire == 0 -> counter = reader.varint()
                else -> reader.skip(wire)
            }
        }

        val rawSecret = secret ?: throw IllegalArgumentException("Migration entry has no secret")
        val parsedType = when (type) {
            1 -> OtpType.HOTP
            2 -> OtpType.TOTP
            else -> OtpType.TOTP
        }
        val parsedDigits = when (digits) {
            1 -> 6
            2 -> 8
            else -> 6
        }
        val parsedAlgorithm = when (algorithm) {
            2 -> HashAlgorithm.SHA256
            3 -> HashAlgorithm.SHA512
            else -> HashAlgorithm.SHA1
        }
        return ParsedOtp(
            type = parsedType,
            issuer = issuer,
            account = name,
            secret = Base32.encode(rawSecret),
            algorithm = parsedAlgorithm,
            digits = parsedDigits,
            period = 30,
            counter = counter,
        )
    }

    private fun queryParam(rawQuery: String?, name: String): String? {
        if (rawQuery.isNullOrBlank()) return null
        return rawQuery.split('&')
            .mapNotNull { part ->
                val index = part.indexOf('=')
                if (index < 0) return@mapNotNull null
                val key = URLDecoder.decode(part.substring(0, index), StandardCharsets.UTF_8)
                if (key != name) return@mapNotNull null
                URLDecoder.decode(part.substring(index + 1), StandardCharsets.UTF_8)
            }
            .firstOrNull()
    }

    private fun decodeBase64(value: String): ByteArray {
        val normalized = value.trim()
        return runCatching {
            Base64.getUrlDecoder().decode(normalized)
        }.recoverCatching {
            Base64.getDecoder().decode(normalized)
        }.getOrElse {
            throw IllegalArgumentException("Invalid migration base64", it)
        }
    }

    private class ProtoReader(private val bytes: ByteArray) {
        private var position = 0

        fun hasMore(): Boolean = position < bytes.size

        fun varint(): Long {
            var result = 0L
            var shift = 0
            while (true) {
                if (position >= bytes.size || shift >= 64) {
                    throw IllegalArgumentException("Invalid protobuf varint")
                }
                val b = bytes[position++].toInt() and 0xFF
                result = result or ((b and 0x7F).toLong() shl shift)
                if (b and 0x80 == 0) return result
                shift += 7
            }
        }

        fun lengthDelimited(): ByteArray {
            val length = varint().toInt()
            if (length < 0 || position + length > bytes.size) {
                throw IllegalArgumentException("Invalid protobuf length")
            }
            val result = bytes.copyOfRange(position, position + length)
            position += length
            return result
        }

        fun skip(wire: Int) {
            when (wire) {
                0 -> varint()
                1 -> position += 8
                2 -> lengthDelimited()
                5 -> position += 4
                else -> throw IllegalArgumentException("Unsupported protobuf wire type: $wire")
            }
            if (position > bytes.size) {
                throw IllegalArgumentException("Truncated protobuf")
            }
        }
    }
}
