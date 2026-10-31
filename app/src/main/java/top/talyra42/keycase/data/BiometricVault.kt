package top.talyra42.keycase.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import top.talyra42.keycase.R
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.biometric.BiometricPrompt.PromptInfo
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Stores the vault key encrypted by an Android Keystore key that requires
 * biometric authentication. The master password slot remains the fallback.
 */
class BiometricVault(private val context: Context) {
    private val prefs = context.getSharedPreferences("keycase.biometric", Context.MODE_PRIVATE)

    fun isAvailable(): Boolean = runCatching {
        BiometricManager.from(context)
            .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS
    }.getOrDefault(false)

    fun isEnrolled(): Boolean = runCatching {
        prefs.contains(KEY_IV) && prefs.contains(KEY_DATA) && keyStore().containsAlias(ALIAS)
    }.getOrDefault(false)

    fun enable(
        activity: FragmentActivity,
        vaultKey: ByteArray,
        onResult: (Boolean, String?) -> Unit,
    ) {
        if (!isAvailable()) {
            onResult(false, "Biometric authentication is not available")
            return
        }
        try {
            clear()
            generateKey()
            val cipher = Cipher.getInstance(TRANSFORMATION).apply {
                init(Cipher.ENCRYPT_MODE, getKey())
            }
            prompt(
                activity = activity,
                title = context.getString(R.string.biometric_enable_title),
                subtitle = context.getString(R.string.biometric_enable_subtitle),
                cipher = cipher,
                onSuccess = { authenticated ->
                    runCatching {
                        val encrypted = authenticated.doFinal(vaultKey)
                        prefs.edit()
                            .putString(KEY_IV, b64(authenticated.iv))
                            .putString(KEY_DATA, b64(encrypted))
                            .apply()
                        true
                    }.getOrElse {
                        clear()
                        false
                    }.let { ok ->
                        if (!ok) onResult(false, "Could not store the biometric key")
                        else onResult(true, null)
                    }
                },
                onError = { message ->
                    clear()
                    onResult(false, message)
                },
            )
        } catch (e: Exception) {
            clear()
            onResult(false, e.message ?: "Could not enable biometric unlock")
        }
    }

    fun unlock(
        activity: FragmentActivity,
        onSuccess: (ByteArray) -> Unit,
        onError: (String) -> Unit,
    ) {
        if (!isEnrolled()) {
            onError("Biometric unlock is not enabled")
            return
        }
        try {
            val iv = Base64.decode(prefs.getString(KEY_IV, null), Base64.NO_WRAP)
            val encrypted = Base64.decode(prefs.getString(KEY_DATA, null), Base64.NO_WRAP)
            val cipher = Cipher.getInstance(TRANSFORMATION).apply {
                init(Cipher.DECRYPT_MODE, getKey(), GCMParameterSpec(128, iv))
            }
            prompt(
                activity = activity,
                title = context.getString(R.string.biometric_unlock_title),
                subtitle = context.getString(R.string.biometric_unlock_subtitle),
                cipher = cipher,
                onSuccess = { authenticated ->
                    runCatching { authenticated.doFinal(encrypted) }
                        .onSuccess(onSuccess)
                        .onFailure { clear(); onError("Biometric key is no longer valid") }
                },
                onError = { message ->
                    if (message.contains("invalidated", ignoreCase = true)) clear()
                    onError(message)
                },
            )
        } catch (e: KeyPermanentlyInvalidatedException) {
            clear()
            onError("Biometric key is no longer valid")
        } catch (e: Exception) {
            onError(e.message ?: "Could not start biometric unlock")
        }
    }

    fun clear() {
        prefs.edit().clear().apply()
        runCatching {
            keyStore().deleteEntry(ALIAS)
        }
    }

    private fun prompt(
        activity: FragmentActivity,
        title: String,
        subtitle: String,
        cipher: Cipher,
        onSuccess: (Cipher) -> Unit,
        onError: (String) -> Unit,
    ) {
        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(context),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    val authenticated = result.cryptoObject?.cipher
                    if (authenticated == null) onError("Biometric authentication failed")
                    else onSuccess(authenticated)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    onError(errString.toString())
                }
            },
        )
        prompt.authenticate(
            PromptInfo.Builder()
                .setTitle(title)
                .setSubtitle(subtitle)
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText(context.getString(R.string.biometric_negative))
                .setConfirmationRequired(false)
                .build(),
            BiometricPrompt.CryptoObject(cipher),
        )
    }

    private fun generateKey() {
        val builder = KeyGenParameterSpec.Builder(
            ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            builder.setUserAuthenticationParameters(
                0,
                KeyProperties.AUTH_BIOMETRIC_STRONG,
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(-1)
        }
        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
            .apply { init(builder.build()) }
            .generateKey()
    }

    private fun getKey(): SecretKey =
        (keyStore().getKey(ALIAS, null) as? SecretKey)
            ?: throw IllegalStateException("Biometric key is missing")

    private fun keyStore(): KeyStore =
        KeyStore.getInstance(KEYSTORE).apply { load(null) }

    private fun b64(bytes: ByteArray): String = Base64.encodeToString(bytes, Base64.NO_WRAP)

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val ALIAS = "keycase.biometric.v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val KEY_IV = "iv"
        const val KEY_DATA = "wrapped"
    }
}
