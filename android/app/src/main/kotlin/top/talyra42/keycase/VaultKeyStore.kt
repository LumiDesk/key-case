package top.talyra42.keycase

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * 生物识别快捷解锁用的密钥保险箱。
 *
 * vault key 由 Android Keystore 里的 AES-256-GCM 密钥加密后再落盘，明文密钥
 * 只在解锁瞬间出现在进程内存里。Keystore 密钥不可导出，因此即使拿到应用私有
 * 目录的密文，也无法在其它设备或未解锁的设备上还原。
 *
 * 说明：这里不在 Keystore 上绑定 setUserAuthenticationRequired——Dart 侧已经用
 * BiometricPrompt 做了用户验证；绑定会让「验证窗口」与 Keystore 的有效期互相
 * 竞争，在部分机型上直接解密失败。取舍记录在 docs/dev/tech-decisions.md。
 */
object VaultKeyStore {
    private const val KEY_ALIAS = "keycase.vault.wrap.v1"
    private const val PREFS = "keycase.secure"
    private const val KEY_CIPHERTEXT = "vault_key_ciphertext"
    private const val KEY_IV = "vault_key_iv"
    private const val KEY_VAULT_ID = "vault_id"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val TAG_BITS = 128

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) return existing.secretKey

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore",
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    fun store(context: Context, vaultKey: ByteArray, vaultId: String): Boolean {
        return try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
            val ciphertext = cipher.doFinal(vaultKey)
            prefs(context).edit()
                .putString(KEY_CIPHERTEXT, Base64.encodeToString(ciphertext, Base64.NO_WRAP))
                .putString(KEY_IV, Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                .putString(KEY_VAULT_ID, vaultId)
                .apply()
            true
        } catch (error: Exception) {
            false
        }
    }

    fun read(context: Context, vaultId: String): ByteArray? {
        return try {
            val prefs = prefs(context)
            val storedVault = prefs.getString(KEY_VAULT_ID, null) ?: return null
            val ciphertext = prefs.getString(KEY_CIPHERTEXT, null) ?: return null
            val iv = prefs.getString(KEY_IV, null) ?: return null
            // 换库/恢复备份后旧密钥必须失效，否则会拿错误的 key 去解新库。
            if (storedVault != vaultId) {
                clear(context)
                return null
            }
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                getOrCreateKey(),
                GCMParameterSpec(TAG_BITS, Base64.decode(iv, Base64.NO_WRAP)),
            )
            cipher.doFinal(Base64.decode(ciphertext, Base64.NO_WRAP))
        } catch (error: Exception) {
            null
        }
    }

    fun clear(context: Context) {
        prefs(context).edit()
            .remove(KEY_CIPHERTEXT)
            .remove(KEY_IV)
            .remove(KEY_VAULT_ID)
            .apply()
        // 同时删除 Keystore 别名：换库/删库后旧密钥不应继续可用。
        try {
            KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                .deleteEntry(KEY_ALIAS)
        } catch (_: Exception) {
            // 个别 ROM 在别名不存在时抛异常；密文已清，降级可接受。
        }
    }
}
