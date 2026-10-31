package top.talyra42.keycase.core.importing

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.bouncycastle.crypto.generators.SCrypt
import top.talyra42.keycase.core.model.HashAlgorithm
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.OtpType
import top.talyra42.keycase.core.model.TotpSecret
import top.talyra42.keycase.core.model.VaultGroup
import top.talyra42.keycase.core.model.VaultItem
import java.nio.charset.StandardCharsets
import java.time.Instant
import java.util.Base64
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class AegisImportException(message: String, cause: Throwable? = null) : Exception(message, cause)

data class AegisImportResult(
    val items: List<VaultItem>,
    val groups: List<VaultGroup>,
    val skipped: Int,
)

/**
 * Reads Aegis vault JSON exports, both plain and password-encrypted.
 *
 * Aegis format:
 *   { version, header: { slots: [...], params: { nonce, tag } }, db: base64 }
 * Password slots use scrypt, AES-256-GCM and a separately stored tag.
 */
object AegisImporter {
    private val json = Json { ignoreUnknownKeys = true }
    const val MAX_FILE_BYTES = 64 * 1024 * 1024
    private const val SLOT_TYPE_PASSWORD = 1
    private const val MAX_SCRYPT_N = 1 shl 20
    private const val MAX_SCRYPT_R = 32
    private const val MAX_SCRYPT_P = 16
    private const val MAX_SCRYPT_MEMORY_BYTES = 256L * 1024 * 1024

    fun import(bytes: ByteArray, password: CharArray? = null): AegisImportResult {
        if (bytes.size > MAX_FILE_BYTES) {
            throw AegisImportException("Aegis 文件过大")
        }
        val root = try {
            json.parseToJsonElement(String(bytes, StandardCharsets.UTF_8)).jsonObject
        } catch (e: Exception) {
            throw AegisImportException("不是有效的 Aegis 导出文件", e)
        }

        val header = root["header"]?.let { it as? JsonObject }
        val slots = header?.get("slots")
            ?.takeIf { it !is JsonNull }
            ?.jsonArray

        val db = if (slots.isNullOrEmpty()) {
            root["db"]?.jsonObject
                ?: throw AegisImportException("Aegis 文件缺少数据库")
        } else {
            val headerObj = header ?: throw AegisImportException("Aegis 文件缺少 header")
            val encrypted = root["db"]?.jsonPrimitive?.contentOrNull
                ?: throw AegisImportException("Aegis 数据库格式错误")
            val params = headerObj["params"]?.jsonObject
                ?: throw AegisImportException("Aegis 文件缺少加密参数")
            decryptDb(encrypted, params, slots, password)
        }

        return parseDb(db)
    }

    private fun decryptDb(
        encryptedBase64: String,
        params: JsonObject,
        slots: JsonArray,
        password: CharArray?,
    ): JsonObject {
        val passwordChars = password
            ?: throw AegisImportException("这个 Aegis 备份已加密，请输入备份密码")
        if (passwordChars.isEmpty()) {
            throw AegisImportException("请输入 Aegis 备份密码")
        }

        val ciphertext = try {
            Base64.getDecoder().decode(encryptedBase64)
        } catch (e: Exception) {
            throw AegisImportException("Aegis 数据库不是有效的 Base64", e)
        }
        val nonce = params.string("nonce")?.let(::hex)
            ?: throw AegisImportException("缺少 nonce")
        val tag = params.string("tag")?.let(::hex)
            ?: throw AegisImportException("缺少 tag")
        val passwordBytes = String(passwordChars).toByteArray(StandardCharsets.UTF_8)

        var lastError: Exception? = null
        for (element in slots) {
            val slot = element as? JsonObject ?: continue
            if (slot.int("type") != SLOT_TYPE_PASSWORD) continue
            try {
                val masterKey = decryptSlot(slot, passwordBytes)
                val plaintext = gcmDecrypt(masterKey, ciphertext, nonce, tag)
                return json.parseToJsonElement(
                    String(plaintext, StandardCharsets.UTF_8),
                ).jsonObject
            } catch (e: Exception) {
                lastError = e
            }
        }
        throw AegisImportException("Aegis 密码错误或备份槽位损坏", lastError)
    }

    private fun decryptSlot(slot: JsonObject, passwordBytes: ByteArray): ByteArray {
        val n = slot.int("n") ?: throw AegisImportException("缺少 scrypt n")
        val r = slot.int("r") ?: throw AegisImportException("缺少 scrypt r")
        val p = slot.int("p") ?: throw AegisImportException("缺少 scrypt p")
        if (n < 2 || n > MAX_SCRYPT_N || n and (n - 1) != 0) {
            throw AegisImportException("scrypt n 超出支持范围")
        }
        if (r !in 1..MAX_SCRYPT_R || p !in 1..MAX_SCRYPT_P) {
            throw AegisImportException("scrypt 参数超出支持范围")
        }
        // scrypt allocates roughly 128*N*r bytes. Reject parameters that would
        // exhaust memory before calling into BouncyCastle.
        if (128L * n * r > MAX_SCRYPT_MEMORY_BYTES) {
            throw AegisImportException("scrypt 内存参数超出支持范围")
        }
        val salt = slot.string("salt")?.let(::hex)
            ?: throw AegisImportException("缺少 scrypt salt")
        val encryptedKey = slot.string("key")?.let(::hex)
            ?: throw AegisImportException("缺少槽位密钥")
        val keyParams = slot["key_params"]?.jsonObject
            ?: throw AegisImportException("缺少槽位参数")
        val nonce = keyParams.string("nonce")?.let(::hex)
            ?: throw AegisImportException("缺少槽位 nonce")
        val tag = keyParams.string("tag")?.let(::hex)
            ?: throw AegisImportException("缺少槽位 tag")

        val derived = SCrypt.generate(passwordBytes, salt, n, r, p, 32)
        return gcmDecrypt(derived, encryptedKey, nonce, tag)
    }

    private fun parseDb(db: JsonObject): AegisImportResult {
        val groups = mutableListOf<VaultGroup>()
        val groupMap = mutableMapOf<String, VaultGroup>()
        db["groups"]?.let { element ->
            if (element is JsonArray) {
                element.forEach { groupElement ->
                    val group = groupElement as? JsonObject ?: return@forEach
                    val oldId = group.string("uuid") ?: return@forEach
                    val name = group.string("name")?.trim().orEmpty()
                    if (name.isBlank()) return@forEach
                    val converted = VaultGroup(
                        id = UUID.randomUUID().toString(),
                        name = name,
                        order = groups.size,
                    )
                    groups.add(converted)
                    groupMap[oldId] = converted
                }
            }
        }

        val now = Instant.now().toString()
        val items = mutableListOf<VaultItem>()
        var skipped = 0
        db["entries"]?.jsonArray?.forEach { element ->
            val entry = element as? JsonObject
            if (entry == null) {
                skipped++
                return@forEach
            }
            val item = runCatching {
                convertEntry(entry, groupMap, now)
            }.getOrNull()
            if (item == null) skipped++ else items.add(item)
        }
        return AegisImportResult(items, groups, skipped)
    }

    private fun convertEntry(
        entry: JsonObject,
        groupMap: Map<String, VaultGroup>,
        now: String,
    ): VaultItem? {
        val info = entry["info"]?.jsonObject ?: return null
        val secret = info.string("secret")?.trim().orEmpty()
        if (secret.isBlank()) return null
        val typeId = entry.string("type")?.lowercase() ?: "totp"
        val otpType = when (typeId) {
            "hotp" -> OtpType.HOTP
            "steam" -> OtpType.STEAM
            else -> OtpType.TOTP
        }
        val defaultDigits = if (otpType == OtpType.STEAM) 5 else 6
        val digits = info.int("digits")?.takeIf { it in 1..8 } ?: defaultDigits
        val period = info.int("period")?.takeIf { it in 1..300 } ?: 30
        val counter = info["counter"]?.jsonPrimitive?.contentOrNull?.toLongOrNull() ?: 0L
        val algorithm = when (info.string("algo")?.uppercase()) {
            "SHA256" -> HashAlgorithm.SHA256
            "SHA512" -> HashAlgorithm.SHA512
            else -> HashAlgorithm.SHA1
        }
        val name = entry.string("name").orEmpty()
        val issuer = entry.string("issuer").orEmpty()
        val notes = entry.string("note").orEmpty()
        val favorite = entry["favorite"]?.jsonPrimitive?.contentOrNull?.toBooleanStrictOrNull() ?: false
        val groupIds = entry["groups"]?.takeIf { it is JsonArray }?.jsonArray
            ?.mapNotNull { groupElement ->
                groupElement.jsonPrimitive.contentOrNull?.let { groupMap[it]?.id }
            }
            .orEmpty()

        return VaultItem(
            id = UUID.randomUUID().toString(),
            kind = ItemKind.TOTP,
            title = issuer.ifBlank { name }.ifBlank { "未命名" },
            issuer = issuer,
            username = name,
            notes = notes,
            favorite = favorite,
            totp = TotpSecret(
                type = otpType,
                secret = secret,
                algorithm = algorithm,
                digits = digits,
                period = period,
                counter = counter,
            ),
            groupIds = groupIds,
            createdAt = now,
            updatedAt = now,
        )
    }

    private fun gcmDecrypt(key: ByteArray, ciphertext: ByteArray, nonce: ByteArray, tag: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            SecretKeySpec(key, "AES"),
            GCMParameterSpec(128, nonce),
        )
        return cipher.doFinal(ciphertext + tag)
    }

    private fun hex(value: String): ByteArray? {
        if (value.length % 2 != 0) return null
        return try {
            ByteArray(value.length / 2) { index ->
                value.substring(index * 2, index * 2 + 2).toInt(16).toByte()
            }
        } catch (e: NumberFormatException) {
            null
        }
    }

    private fun JsonObject.string(name: String): String? =
        this[name]?.jsonPrimitive?.contentOrNull

    private fun JsonObject.int(name: String): Int? =
        this[name]?.jsonPrimitive?.intOrNull
}
