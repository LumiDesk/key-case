package top.talyra42.keycase.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * The decrypted vault payload. Everything in this object lives only in memory
 * and inside the encrypted container on disk.
 */
@Serializable
data class VaultData(
    val schema: Int = 1,
    val vaultId: String,
    val createdAt: String,
    val items: List<VaultItem> = emptyList(),
    val groups: List<VaultGroup> = emptyList(),
)

@Serializable
data class VaultItem(
    val id: String,
    val kind: ItemKind = ItemKind.LOGIN,
    val title: String = "",
    val issuer: String = "",
    val username: String = "",
    val password: String = "",
    val urls: List<String> = emptyList(),
    val notes: String = "",
    val totp: TotpSecret? = null,
    val icon: IconRef? = null,
    val groupIds: List<String> = emptyList(),
    val favorite: Boolean = false,
    val createdAt: String = "",
    val updatedAt: String = "",
    val deletedAt: String? = null,
)

@Serializable
enum class ItemKind {
    @SerialName("login") LOGIN,
    @SerialName("totp") TOTP,
}

@Serializable
data class VaultGroup(
    val id: String,
    val name: String,
    val order: Int = 0,
)

/**
 * TOTP/HOTP/Steam secret. The secret is stored as Base32, matching otpauth.
 */
@Serializable
data class TotpSecret(
    val type: OtpType = OtpType.TOTP,
    val secret: String,
    val algorithm: HashAlgorithm = HashAlgorithm.SHA1,
    val digits: Int = 6,
    val period: Int = 30,
    val counter: Long = 0,
)

@Serializable
enum class OtpType {
    @SerialName("totp") TOTP,
    @SerialName("hotp") HOTP,
    @SerialName("steam") STEAM,
}

@Serializable
enum class HashAlgorithm {
    @SerialName("SHA1") SHA1,
    @SerialName("SHA256") SHA256,
    @SerialName("SHA512") SHA512,
}

/**
 * Icon reference. A pack icon is looked up from the installed pack at render
 * time; a custom icon stores its bytes base64-encoded in the vault.
 */
@Serializable
data class IconRef(
    val kind: String = "pack",
    val value: String = "",
    val mime: String = "",
)
