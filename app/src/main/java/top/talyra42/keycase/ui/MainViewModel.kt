package top.talyra42.keycase.ui

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import top.talyra42.keycase.core.importing.AegisImporter
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.TotpSecret
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.model.VaultGroup
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.core.otp.GoogleMigrationParser
import top.talyra42.keycase.core.otp.withNextCounter
import top.talyra42.keycase.data.AppSettings
import top.talyra42.keycase.data.CodeGrouping
import top.talyra42.keycase.data.DarkMode
import top.talyra42.keycase.data.SettingsRepository
import top.talyra42.keycase.data.VaultBackupService
import top.talyra42.keycase.data.VaultImportService
import top.talyra42.keycase.data.VaultRepository
import java.time.Instant
import java.util.UUID

data class UiState(
    val vaultExists: Boolean = false,
    val locked: Boolean = true,
    val data: VaultData? = null,
    val busy: Boolean = false,
    val error: String? = null,
    val message: String? = null,
)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val vault = VaultRepository(application)
    private val backups = VaultBackupService(application)
    private val settingsStore = SettingsRepository(application)

    private val _state = MutableStateFlow(
        UiState(vaultExists = vault.exists(), locked = true),
    )
    val state = _state.asStateFlow()

    private val _settings = MutableStateFlow(settingsStore.load())
    val settings = _settings.asStateFlow()

    private var keepUnlockedForExternal = false

    fun createVault(password: String, confirm: String) {
        val trimmed = password.trim()
        when {
            trimmed.length < 8 -> {
                _state.update { it.copy(error = "主密码至少 8 位") }
                return
            }
            password != confirm -> {
                _state.update { it.copy(error = "两次输入的主密码不一致") }
                return
            }
        }

        runVaultOperation {
            val chars = password.toCharArray()
            try {
                val empty = VaultData(
                    vaultId = "",
                    createdAt = Instant.now().toString(),
                )
                val created = vault.create(chars, empty)
                _state.update {
                    it.copy(
                        vaultExists = true,
                        locked = false,
                        data = created.data,
                        busy = false,
                        error = null,
                    )
                }
            } finally {
                chars.fill('\u0000')
            }
        }
    }

    fun unlock(password: String) {
        if (!vault.exists()) {
            _state.update { it.copy(vaultExists = false, locked = true) }
            return
        }

        runVaultOperation {
            val chars = password.toCharArray()
            try {
                val unlocked = vault.unlock(chars)
                top.talyra42.keycase.ui.icons.AegisIconPack.prefetch(
                    getApplication<Application>(),
                    unlocked.data.items.map { it.title },
                )
                _state.update {
                    it.copy(
                        vaultExists = true,
                        locked = false,
                        data = unlocked.data,
                        busy = false,
                        error = null,
                    )
                }
            } finally {
                chars.fill('\u0000')
            }
        }
    }

    fun lock() {
        vault.lock()
        _state.update {
            it.copy(locked = true, data = null, busy = false)
        }
    }

    fun copyVaultKeyForBiometric(): ByteArray? = vault.copyVaultKey()

    fun vaultBytesForBiometric(): ByteArray? =
        if (vault.exists()) runCatching { vault.readBytes() }.getOrNull() else null

    fun unlockWithVaultKey(vaultKey: ByteArray) {
        if (!vault.exists()) {
            vaultKey.fill(0)
            _state.update { it.copy(vaultExists = false, locked = true) }
            return
        }
        runVaultOperation {
            try {
                val unlocked = vault.unlockWithVaultKey(vaultKey)
                top.talyra42.keycase.ui.icons.AegisIconPack.prefetch(
                    getApplication<Application>(),
                    unlocked.data.items.map { it.title },
                )
                _state.update {
                    it.copy(
                        vaultExists = true,
                        locked = false,
                        data = unlocked.data,
                        busy = false,
                        error = null,
                    )
                }
            } finally {
                vaultKey.fill(0)
            }
        }
    }

    /**
     * Call before starting a document picker or scanner. That external
     * activity stops MainActivity; without this flag the vault would lock and
     * the returned result would be lost.
     */
    fun prepareExternalActivity() {
        keepUnlockedForExternal = true
    }

    /**
     * Consumes the one-shot "an external picker/activity is open" flag.
     * [top.talyra42.keycase.data.AutoLockManager] checks this on process stop.
     */
    fun consumeExternalProtection(): Boolean {
        if (!keepUnlockedForExternal) return false
        keepUnlockedForExternal = false
        return true
    }

    fun upsertItem(item: VaultItem, groupName: String) {
        val data = _state.value.data ?: return
        val now = Instant.now().toString()
        var groups = data.groups

        val groupIds = if (groupName.isBlank()) {
            item.groupIds
        } else {
            val existing = groups.firstOrNull { it.name.equals(groupName.trim(), ignoreCase = true) }
            val group = existing ?: VaultGroup(
                id = UUID.randomUUID().toString(),
                name = groupName.trim(),
                order = groups.size,
            )
            if (existing == null) groups = groups + group
            listOf(group.id)
        }

        val updated = item.copy(
            groupIds = groupIds,
            createdAt = item.createdAt.ifBlank { now },
            updatedAt = now,
        )
        val items = if (data.items.any { it.id == item.id }) {
            data.items.map { if (it.id == item.id) updated else it }
        } else {
            data.items + updated
        }

        persist(data.copy(items = items, groups = groups))
    }

    /**
     * Advances a counter-based HOTP item. The next code is derived from the
     * stored counter, so this is the only mutation path for HOTP.
     */
    fun advanceHotp(itemId: String) {
        val data = _state.value.data ?: return
        val now = Instant.now().toString()
        val items = data.items.map { item ->
            val secret = item.totp
            if (item.id == itemId && secret != null && secret.type == top.talyra42.keycase.core.model.OtpType.HOTP) {
                item.copy(totp = secret.withNextCounter(), updatedAt = now)
            } else {
                item
            }
        }
        persist(data.copy(items = items))
    }

    fun toggleFavorite(itemId: String) {
        val data = _state.value.data ?: return
        val now = Instant.now().toString()
        persist(
            data.copy(
                items = data.items.map {
                    if (it.id == itemId) {
                        it.copy(favorite = !it.favorite, updatedAt = now)
                    } else {
                        it
                    }
                },
            ),
        )
    }

    fun deleteItem(itemId: String) {
        val data = _state.value.data ?: return
        val now = Instant.now().toString()
        persist(
            data.copy(
                items = data.items.map {
                    if (it.id == itemId) it.copy(deletedAt = now, updatedAt = now) else it
                },
            ),
        )
    }

    fun restoreItem(itemId: String) {
        val data = _state.value.data ?: return
        val now = Instant.now().toString()
        persist(
            data.copy(
                items = data.items.map {
                    if (it.id == itemId) it.copy(deletedAt = null, updatedAt = now) else it
                },
            ),
        )
    }

    fun purgeItem(itemId: String) {
        val data = _state.value.data ?: return
        persist(data.copy(items = data.items.filterNot { it.id == itemId }))
    }

    fun emptyTrash() {
        val data = _state.value.data ?: return
        persist(data.copy(items = data.items.filter { it.deletedAt == null }))
    }

    fun deleteVault() {
        vault.deleteAll()
        _state.update {
            UiState(vaultExists = false, locked = true)
        }
    }

    fun changeMasterPassword(current: String, newPassword: String, confirm: String) {
        when {
            newPassword.length < 8 -> {
                _state.update { it.copy(error = "新主密码至少 8 位") }
                return
            }
            newPassword != confirm -> {
                _state.update { it.copy(error = "两次输入的新主密码不一致") }
                return
            }
        }

        runVaultOperation {
            val currentChars = current.toCharArray()
            val newChars = newPassword.toCharArray()
            try {
                val bytes = vault.changePassword(currentChars, newChars)
                autoBackupIfConfigured(bytes)
                _state.update {
                    it.copy(
                        data = vault.currentData(),
                        busy = false,
                        error = null,
                    )
                }
            } finally {
                currentChars.fill('\u0000')
                newChars.fill('\u0000')
            }
        }
    }

    fun addTotp(issuer: String, account: String, secret: String, digits: Int, period: Int) {
        val now = Instant.now().toString()
        val item = VaultItem(
            id = UUID.randomUUID().toString(),
            kind = ItemKind.TOTP,
            title = issuer.trim().ifBlank { account.trim() },
            issuer = issuer.trim(),
            username = account.trim(),
            totp = TotpSecret(
                secret = secret.trim().uppercase().replace(" ", ""),
                digits = digits,
                period = period,
            ),
            createdAt = now,
            updatedAt = now,
        )
        upsertItem(item, "")
    }

    fun importGoogleMigration(link: String) {
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            try {
                val parsed = GoogleMigrationParser.parse(link.trim())
                val current = vault.currentData() ?: error("Vault is locked")
                val merged = VaultImportService.mergeGoogle(current, parsed)
                val bytes = vault.persist(merged.data)
                autoBackupIfConfigured(bytes)
                _state.update {
                    it.copy(
                        data = merged.data,
                        busy = false,
                        error = null,
                        message = if (merged.skippedDuplicates > 0) {
                            "已导入 ${merged.imported} 个令牌（跳过 ${merged.skippedDuplicates} 个重复）"
                        } else {
                            "已导入 ${merged.imported} 个令牌"
                        },
                    )
                }
            } catch (e: Exception) {
                _state.update {
                    it.copy(busy = false, error = e.message ?: "Google Authenticator 导入失败")
                }
            }
        }
    }

    fun clearError() {
        _state.update { it.copy(error = null) }
    }

    fun clearMessage() {
        _state.update { it.copy(message = null) }
    }

    fun setAccent(index: Int) {
        val safe = index.coerceIn(0, 4)
        updateSettings { it.copy(accentIndex = safe, customAccent = null) }
    }

    fun setCustomAccent(argb: Int) {
        updateSettings { it.copy(customAccent = argb) }
    }

    fun setDarkMode(mode: DarkMode) {
        updateSettings { it.copy(darkMode = mode) }
    }

    fun setShowTokenCodes(show: Boolean) {
        updateSettings { it.copy(showTokenCodes = show) }
    }

    fun setShowNextToken(show: Boolean) {
        updateSettings { it.copy(showNextToken = show) }
    }

    fun setSecureScreen(enabled: Boolean) {
        updateSettings { it.copy(secureScreen = enabled) }
    }

    fun setAutoLockSeconds(seconds: Int) {
        updateSettings { it.copy(autoLockSeconds = seconds.coerceIn(0, 300)) }
    }

    fun setCodeGrouping(grouping: CodeGrouping) {
        updateSettings { it.copy(codeGrouping = grouping) }
    }

    fun setAutoBackup(enabled: Boolean) {
        updateSettings { it.copy(autoBackup = enabled) }
    }

    fun setBackupFolder(uri: String, displayName: String) {
        updateSettings {
            it.copy(
                backupTreeUri = uri,
                backupFolderName = displayName,
                autoBackup = true,
            )
        }
    }

    private fun updateSettings(transform: (AppSettings) -> AppSettings) {
        val next = transform(_settings.value)
        _settings.value = next
        settingsStore.save(next)
    }

    fun backupNow() {
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            try {
                val bytes = vault.readBytes()
                writeBackup(bytes)
                _state.update { it.copy(busy = false, message = "备份已保存") }
            } catch (e: Exception) {
                _state.update {
                    it.copy(busy = false, error = e.message ?: "备份失败")
                }
            }
        }
    }

    fun exportBackup(uri: Uri) {
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            try {
                backups.export(uri, vault.readBytes())
                _state.update { it.copy(busy = false) }
            } catch (e: Exception) {
                _state.update {
                    it.copy(busy = false, error = e.message ?: "备份失败")
                }
            }
        }
    }

    fun importBackup(uri: Uri, password: String) {
        if (password.length < 1) {
            _state.update { it.copy(error = "请输入备份的主密码") }
            return
        }
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            val chars = password.toCharArray()
            try {
                val bytes = backups.readLimited(uri)
                val imported = vault.replaceWithBackup(bytes, chars)
                autoBackupIfConfigured(bytes)
                _state.update {
                    it.copy(
                        vaultExists = true,
                        locked = false,
                        data = imported.data,
                        busy = false,
                        error = null,
                        message = "备份导入成功，原保险库已保留为安全副本",
                    )
                }
            } catch (e: Exception) {
                _state.update {
                    it.copy(busy = false, error = e.message ?: "无法导入备份")
                }
            } finally {
                chars.fill('\u0000')
            }
        }
    }

    fun importAegis(uri: Uri, password: String) {
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            val chars = password.toCharArray()
            try {
                val bytes = backups.readLimited(uri)
                val result = AegisImporter.import(bytes, chars)
                val current = vault.currentData() ?: error("Vault is locked")
                val merged = VaultImportService.mergeAegis(current, result)
                val sealedBytes = vault.persist(merged.data)
                autoBackupIfConfigured(sealedBytes)
                _state.update {
                    it.copy(
                        data = merged.data,
                        busy = false,
                        error = null,
                        message = if (merged.skippedDuplicates > 0) {
                            "已导入 ${merged.imported} 个条目（跳过 ${merged.skippedDuplicates} 个重复）"
                        } else {
                            "已导入 ${merged.imported} 个条目"
                        },
                    )
                }
            } catch (e: Exception) {
                _state.update {
                    it.copy(busy = false, error = e.message ?: "Aegis 导入失败")
                }
            } finally {
                chars.fill('\u0000')
            }
        }
    }

    override fun onCleared() {
        vault.lock()
        super.onCleared()
    }

    private fun autoBackupIfConfigured(bytes: ByteArray) {
        val settings = _settings.value
        if (!settings.autoBackup || settings.backupTreeUri.isBlank()) return
        runCatching { writeBackup(bytes) }
    }

    private fun writeBackup(bytes: ByteArray) {
        val current = _settings.value
        if (current.backupTreeUri.isBlank()) error("请先选择备份目录")
        backups.writeSnapshot(current.backupTreeUri, bytes)
        val now = System.currentTimeMillis()
        updateSettings { it.copy(lastBackupAt = now) }
    }

    private fun persist(data: VaultData) {
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            try {
                val bytes = vault.persist(data)
                _state.update {
                    it.copy(data = vault.currentData() ?: data, busy = false, error = null)
                }
                autoBackupIfConfigured(bytes)
            } catch (e: Exception) {
                _state.update {
                    it.copy(busy = false, error = e.message ?: "保存失败")
                }
            }
        }
    }

    private fun runVaultOperation(block: suspend () -> Unit) {
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            try {
                block()
            } catch (e: Exception) {
                _state.update {
                    it.copy(busy = false, error = e.message ?: "操作失败")
                }
            }
        }
    }
}
