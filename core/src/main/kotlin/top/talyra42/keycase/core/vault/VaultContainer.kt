package top.talyra42.keycase.core.vault

import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import top.talyra42.keycase.core.crypto.Aead
import top.talyra42.keycase.core.crypto.Codec
import top.talyra42.keycase.core.crypto.Crypto
import top.talyra42.keycase.core.crypto.KdfParams
import top.talyra42.keycase.core.model.VaultData
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.time.Instant
import java.util.UUID
import java.util.zip.GZIPInputStream
import java.util.zip.GZIPOutputStream

class VaultFormatException(message: String, cause: Throwable? = null) : Exception(message, cause)

@Serializable
data class VaultHeader(
    val formatVersion: Int = 1,
    val vaultId: String,
    val cipher: String = "AES-256-GCM",
    val compression: String = "gzip",
    val createdAt: String,
    val payloadNonce: String,
    val slots: List<KeySlot>,
)

@Serializable
data class KeySlot(
    val id: String,
    val type: String,
    val salt: String,
    val kdf: KdfParams,
    val nonce: String,
    val wrappedKey: String,
)

/**
 * Single-file encrypted vault container.
 *
 * Layout:
 *   magic "TKV1" (4 bytes)
 *   format version (1 byte)
 *   header length (4 bytes, big endian)
 *   header JSON (UTF-8)
 *   payload ciphertext (AES-256-GCM, tag included)
 *
 * The payload is gzip(JSON(VaultData)) encrypted with a random 256-bit vault
 * key. The vault key is wrapped by a password-derived Argon2id key in a slot.
 */
object VaultContainer {
    const val MAGIC = "TKV1"
    const val FORMAT_VERSION: Int = 1
    const val FILE_HEADER_SIZE: Int = 9
    private const val MAX_HEADER_BYTES: Int = 1024 * 1024
    private const val MAX_PAYLOAD_BYTES: Int = 64 * 1024 * 1024
    private const val SLOT_TYPE_PASSWORD = "password"

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    fun create(
        password: CharArray,
        data: VaultData,
        kdfParams: KdfParams = KdfParams(),
    ): ByteArray {
        require(password.isNotEmpty()) { "password must not be empty" }

        val vaultId = UUID.randomUUID().toString()
        val now = Instant.now().toString()
        val vaultKey = Crypto.randomBytes(Crypto.KEY_SIZE)
        val salt = Crypto.randomBytes(Crypto.SALT_SIZE)

        val slotId = UUID.randomUUID().toString()
        val passwordKey = Crypto.argon2id(password, salt, kdfParams)
        val wrappedKey = Aead.encrypt(
            key = passwordKey,
            plaintext = vaultKey,
            aad = slotAad(slotId),
        )

        val payload = data.copy(
            vaultId = vaultId,
            createdAt = data.createdAt.ifBlank { now },
        )
        val compressed = gzip(json.encodeToString(payload).toByteArray(StandardCharsets.UTF_8))
        val payloadNonce = Crypto.randomBytes(Crypto.NONCE_SIZE)
        val ciphertext = Aead.encryptWithNonce(
            key = vaultKey,
            nonce = payloadNonce,
            plaintext = compressed,
            aad = payloadAad(vaultId),
        ).ciphertext

        val header = VaultHeader(
            vaultId = vaultId,
            createdAt = now,
            payloadNonce = Codec.b64(payloadNonce),
            slots = listOf(
                KeySlot(
                    id = slotId,
                    type = SLOT_TYPE_PASSWORD,
                    salt = Codec.b64(salt),
                    kdf = kdfParams,
                    nonce = Codec.b64(wrappedKey.nonce),
                    wrappedKey = Codec.b64(wrappedKey.ciphertext),
                ),
            ),
        )

        val headerBytes = json.encodeToString(header).toByteArray(StandardCharsets.UTF_8)
        return ByteBuffer.allocate(FILE_HEADER_SIZE + headerBytes.size + ciphertext.size)
            .put(MAGIC.toByteArray(StandardCharsets.US_ASCII))
            .put(FORMAT_VERSION.toByte())
            .putInt(headerBytes.size)
            .put(headerBytes)
            .put(ciphertext)
            .array()
    }

    fun open(password: CharArray, bytes: ByteArray): VaultData {
        val parsed = parse(bytes)
        val header = parsed.header
        val slot = header.slots.firstOrNull { it.type == SLOT_TYPE_PASSWORD }
            ?: throw VaultFormatException("No password slot in vault")

        val passwordKey = try {
            Crypto.argon2id(password, Codec.unb64(slot.salt), slot.kdf)
        } catch (e: Exception) {
            throw VaultFormatException("Unable to derive password key", e)
        }

        val vaultKey = try {
            Aead.decrypt(
                key = passwordKey,
                box = top.talyra42.keycase.core.crypto.SealedBox(
                    nonce = Codec.unb64(slot.nonce),
                    ciphertext = Codec.unb64(slot.wrappedKey),
                ),
                aad = slotAad(slot.id),
            )
        } catch (e: Exception) {
            throw VaultFormatException("Wrong password or corrupted key slot", e)
        }

        val plaintext = try {
            Aead.decrypt(
                key = vaultKey,
                box = top.talyra42.keycase.core.crypto.SealedBox(
                    nonce = Codec.unb64(header.payloadNonce),
                    ciphertext = parsed.ciphertext,
                ),
                aad = payloadAad(header.vaultId),
            )
        } catch (e: Exception) {
            throw VaultFormatException("Wrong password or corrupted payload", e)
        }

        return try {
            val data = json.decodeFromString<VaultData>(
                gunzip(plaintext).toString(StandardCharsets.UTF_8),
            )
            require(data.vaultId == header.vaultId) { "Vault id mismatch" }
            data
        } catch (e: Exception) {
            throw VaultFormatException("Invalid vault payload", e)
        }
    }

    fun inspect(bytes: ByteArray): VaultHeader = parse(bytes).header

    private data class ParsedVault(
        val header: VaultHeader,
        val ciphertext: ByteArray,
    )

    private fun parse(bytes: ByteArray): ParsedVault {
        if (bytes.size < FILE_HEADER_SIZE) {
            throw VaultFormatException("File is too small")
        }

        val buffer = ByteBuffer.wrap(bytes)
        val magic = ByteArray(4)
        buffer.get(magic)
        if (String(magic, StandardCharsets.US_ASCII) != MAGIC) {
            throw VaultFormatException("Bad vault magic")
        }

        val version = buffer.get().toInt() and 0xFF
        if (version != FORMAT_VERSION) {
            throw VaultFormatException("Unsupported vault version: $version")
        }

        val headerLength = buffer.int
        if (headerLength <= 0 || headerLength > MAX_HEADER_BYTES) {
            throw VaultFormatException("Invalid header length: $headerLength")
        }
        if (headerLength > buffer.remaining()) {
            throw VaultFormatException("Truncated header")
        }

        val headerBytes = ByteArray(headerLength)
        buffer.get(headerBytes)
        val payloadLength = buffer.remaining()
        if (payloadLength <= 0 || payloadLength > MAX_PAYLOAD_BYTES) {
            throw VaultFormatException("Invalid payload length: $payloadLength")
        }
        val ciphertext = ByteArray(payloadLength)
        buffer.get(ciphertext)

        val header = try {
            json.decodeFromString<VaultHeader>(headerBytes.toString(StandardCharsets.UTF_8))
        } catch (e: Exception) {
            throw VaultFormatException("Invalid vault header", e)
        }

        return ParsedVault(header, ciphertext)
    }

    private fun payloadAad(vaultId: String): ByteArray =
        "$MAGIC|$FORMAT_VERSION|$vaultId|payload".toByteArray(StandardCharsets.UTF_8)

    private fun slotAad(slotId: String): ByteArray =
        "$MAGIC|$FORMAT_VERSION|$slotId|$SLOT_TYPE_PASSWORD".toByteArray(StandardCharsets.UTF_8)

    private fun gzip(data: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        GZIPOutputStream(out).use { it.write(data) }
        return out.toByteArray()
    }

    private fun gunzip(data: ByteArray): ByteArray =
        GZIPInputStream(ByteArrayInputStream(data)).use { it.readBytes() }
}
