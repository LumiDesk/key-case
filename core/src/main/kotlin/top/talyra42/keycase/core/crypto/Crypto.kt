package top.talyra42.keycase.core.crypto

import kotlinx.serialization.Serializable
import org.bouncycastle.crypto.generators.Argon2BytesGenerator
import org.bouncycastle.crypto.params.Argon2Parameters
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Argon2id parameters. The defaults are calibrated for a modern phone; tests
 * use much smaller values to stay fast.
 */
@Serializable
data class KdfParams(
    val memoryKib: Int = 32 * 1024,
    val iterations: Int = 3,
    val parallelism: Int = 2,
)

data class SealedBox(
    val nonce: ByteArray,
    val ciphertext: ByteArray,
)

object Crypto {
    const val KEY_SIZE = 32
    const val NONCE_SIZE = 12
    const val TAG_BITS = 128
    const val SALT_SIZE = 16

    private val random = SecureRandom()

    fun randomBytes(size: Int): ByteArray {
        require(size > 0) { "size must be positive" }
        return ByteArray(size).also(random::nextBytes)
    }

    fun argon2id(password: CharArray, salt: ByteArray, params: KdfParams): ByteArray {
        require(password.isNotEmpty()) { "password must not be empty" }
        require(salt.size >= 8) { "salt is too short" }
        require(params.memoryKib >= 8 * params.parallelism) { "Argon2 memory is too small" }
        require(params.iterations >= 1) { "Argon2 iterations must be >= 1" }

        val generator = Argon2BytesGenerator()
        val argonParams = Argon2Parameters.Builder(Argon2Parameters.ARGON2_id)
            .withSalt(salt)
            .withMemoryAsKB(params.memoryKib)
            .withIterations(params.iterations)
            .withParallelism(params.parallelism)
            .build()
        generator.init(argonParams)

        return ByteArray(KEY_SIZE).also { output ->
            generator.generateBytes(password, output)
        }
    }

    fun hmacSha256(key: ByteArray, data: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(data)
    }

    fun constantTimeEquals(a: ByteArray, b: ByteArray): Boolean = MessageDigest.isEqual(a, b)
}

object Aead {
    fun encrypt(key: ByteArray, plaintext: ByteArray, aad: ByteArray): SealedBox =
        encryptWithNonce(key, Crypto.randomBytes(Crypto.NONCE_SIZE), plaintext, aad)

    fun encryptWithNonce(
        key: ByteArray,
        nonce: ByteArray,
        plaintext: ByteArray,
        aad: ByteArray,
    ): SealedBox {
        require(key.size == Crypto.KEY_SIZE) { "AES-256 key must be 32 bytes" }
        require(nonce.size == Crypto.NONCE_SIZE) { "GCM nonce must be 12 bytes" }

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.ENCRYPT_MODE,
            SecretKeySpec(key, "AES"),
            GCMParameterSpec(Crypto.TAG_BITS, nonce),
        )
        cipher.updateAAD(aad)
        return SealedBox(nonce, cipher.doFinal(plaintext))
    }

    fun decrypt(key: ByteArray, box: SealedBox, aad: ByteArray): ByteArray {
        require(key.size == Crypto.KEY_SIZE) { "AES-256 key must be 32 bytes" }

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            SecretKeySpec(key, "AES"),
            GCMParameterSpec(Crypto.TAG_BITS, box.nonce),
        )
        cipher.updateAAD(aad)
        return cipher.doFinal(box.ciphertext)
    }
}

object Codec {
    fun b64(bytes: ByteArray): String = Base64.getEncoder().encodeToString(bytes)

    fun unb64(value: String): ByteArray = Base64.getDecoder().decode(value)
}
