package top.talyra42.keycase.data

import android.content.Context
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import top.talyra42.keycase.core.crypto.KdfParams
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.vault.UnlockedVault
import top.talyra42.keycase.core.vault.VaultContainer

/**
 * Owns the on-disk vault, the unlocked session and the write mutex. The
 * ViewModel owns UI state only; keeping crypto/session ownership here makes the
 * critical "one writer, one vault key" rules explicit.
 */
class VaultRepository(
    context: Context,
    private val store: AndroidVaultStore = AndroidVaultStore(context),
) {
    private val saveMutex = Mutex()
    private var session: UnlockedVault? = null

    fun exists(): Boolean = store.exists()

    fun currentData(): VaultData? = session?.data

    fun currentVaultId(): String? = session?.data?.vaultId

    fun copyVaultKey(): ByteArray? = session?.vaultKey?.copyOf()

    fun readBytes(): ByteArray = store.read()

    fun create(password: CharArray, data: VaultData): UnlockedVault {
        lock()
        val created = VaultContainer.createSession(password, data, KdfParams())
        store.write(created.bytes)
        session = created.session
        return created.session
    }

    fun unlock(password: CharArray): UnlockedVault {
        lock()
        val unlocked = VaultContainer.unlock(password, store.read())
        session = unlocked
        return unlocked
    }

    fun unlockWithVaultKey(vaultKey: ByteArray): UnlockedVault {
        lock()
        val unlocked = VaultContainer.unlockWithVaultKey(store.read(), vaultKey)
        session = unlocked
        return unlocked
    }

    suspend fun persist(data: VaultData): ByteArray = saveMutex.withLock {
        val current = session ?: error("Vault is locked")
        val next = current.withData(data)
        val bytes = VaultContainer.seal(next)
        store.write(bytes)
        session = next
        bytes
    }

    suspend fun changePassword(currentPassword: CharArray, newPassword: CharArray): ByteArray =
        saveMutex.withLock {
            val current = session ?: error("Vault is locked")
            val onDisk = store.read()
            VaultContainer.unlock(currentPassword, onDisk).close()
            val rotated = VaultContainer.changePasswordSession(current, newPassword, KdfParams())
            store.write(rotated.bytes)
            current.close()
            session = rotated.session
            rotated.bytes
        }

    /**
     * Replaces the live vault with an already decrypted backup. The current
     * ciphertext is copied first so a failed replacement can be investigated.
     */
    suspend fun replaceWithBackup(bytes: ByteArray, password: CharArray): UnlockedVault =
        saveMutex.withLock {
            val imported = VaultContainer.unlock(password, bytes)
            try {
                store.backupBeforeImport()
                store.write(bytes)
            } catch (e: Exception) {
                imported.close()
                throw e
            }
            session?.close()
            session = imported
            imported
        }

    fun lock() {
        session?.close()
        session = null
    }

    fun deleteAll() {
        lock()
        store.deleteAll()
    }
}
