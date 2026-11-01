package top.talyra42.keycase.ui

import android.app.Application
import android.content.Context
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
import top.talyra42.keycase.data.AutoBackupManager
import top.talyra42.keycase.data.VaultRepository
import java.io.ByteArrayOutputStream
import java.time.Instant
import java.util.UUID

enum class DarkMode { SYSTEM, LIGHT, DARK }

enum class CodeGrouping { AUTO, THREE, FOUR, NONE }

data class AppSettings(
    val accentIndex: Int = 0,
    val customAccent: Int? = null,
    val darkMode: DarkMode = DarkMode.SYSTEM,
    val showTokenCodes: Boolean = true,
    val showNextToken: Boolean = false,
    val secureScreen: Boolean = false,
    val autoLockSeconds: Int = 0,
    val codeGrouping: CodeGrouping = CodeGrouping.AUTO,
    val autoBackup: Boolean = false,
    val backupTreeUri: String = "",
    val backupFolderName: String = "",
    val lastBackupAt: Long = 0L,
)

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
    private val prefs = application.getSharedPreferences("keycase.settings.v2", Context.MODE_PRIVATE)

    private val _state = MutableStateFlow(
        UiState(vaultExists = vault.exists(), locked = true),
    )
    val state = _state.asStateFlow()

    private val _settings = MutableStateFlow(loadSettings())
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
                val now = Instant.now().toString()
                val existingSecrets = current.items
                    .mapNotNull { it.totp?.secret }
                    .toMutableSet()
                val unique = parsed.filter { existingSecrets.add(it.secret) }
                val skipped = parsed.size - unique.size
                val items = unique.map { otp ->
                    VaultItem(
                        id = UUID.randomUUID().toString(),
                        kind = ItemKind.TOTP,
                        title = otp.issuer.ifBlank { otp.account }.ifBlank { "动态令牌" },
                        issuer = otp.issuer,
                        username = otp.account,
                        totp = TotpSecret(
                            type = otp.type,
                            secret = otp.secret,
                            algorithm = otp.algorithm,
                            digits = otp.digits,
                            period = otp.period,
                            counter = otp.counter,
                        ),
                        createdAt = now,
                        updatedAt = now,
                    )
                }
                val nextData = current.copy(items = current.items + items)
                val bytes = vault.persist(nextData)
                autoBackupIfConfigured(bytes)
                _state.update {
                    it.copy(
                        data = nextData,
                        busy = false,
                        error = null,
                        message = if (skipped > 0) {
                            "已导入 ${items.size} 个令牌（跳过 $skipped 个重复）"
                        } else {
                            "已导入 ${items.size} 个令牌"
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
        _settings.update { it.copy(accentIndex = safe, customAccent = null) }
        prefs.edit().putInt(KEY_ACCENT, safe).remove(KEY_CUSTOM).apply()
    }

    fun setCustomAccent(argb: Int) {
        _settings.update { it.copy(customAccent = argb) }
        prefs.edit().putInt(KEY_CUSTOM, argb).apply()
    }

    fun setDarkMode(mode: DarkMode) {
        _settings.update { it.copy(darkMode = mode) }
        prefs.edit().putString(KEY_DARK, mode.name).apply()
    }

    fun setShowTokenCodes(show: Boolean) {
        _settings.update { it.copy(showTokenCodes = show) }
        prefs.edit().putBoolean(KEY_SHOW_CODES, show).apply()
    }

    fun setShowNextToken(show: Boolean) {
        _settings.update { it.copy(showNextToken = show) }
        prefs.edit().putBoolean(KEY_NEXT_TOKEN, show).apply()
    }

    fun setSecureScreen(enabled: Boolean) {
        _settings.update { it.copy(secureScreen = enabled) }
        prefs.edit().putBoolean(KEY_SECURE_SCREEN, enabled).apply()
    }

    fun setAutoLockSeconds(seconds: Int) {
        val safe = seconds.coerceIn(0, 300)
        _settings.update { it.copy(autoLockSeconds = safe) }
        prefs.edit().putInt(KEY_AUTO_LOCK, safe).apply()
    }

    fun setCodeGrouping(grouping: CodeGrouping) {
        _settings.update { it.copy(codeGrouping = grouping) }
        prefs.edit().putString(KEY_CODE_GROUPING, grouping.name).apply()
    }

    fun setAutoBackup(enabled: Boolean) {
        _settings.update { it.copy(autoBackup = enabled) }
        prefs.edit().putBoolean(KEY_AUTO_BACKUP, enabled).apply()
    }

    fun setBackupFolder(uri: String, displayName: String) {
        _settings.update {
            it.copy(
                backupTreeUri = uri,
                backupFolderName = displayName,
                autoBackup = true,
            )
        }
        prefs.edit()
            .putString(KEY_BACKUP_TREE, uri)
            .putString(KEY_BACKUP_NAME, displayName)
            .putBoolean(KEY_AUTO_BACKUP, true)
            .apply()
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
        val app = getApplication<Application>()
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            try {
                app.contentResolver.openOutputStream(uri)?.use { out ->
                    out.write(vault.readBytes())
                } ?: error("无法写入备份文件")
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
        val app = getApplication<Application>()
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            val chars = password.toCharArray()
            try {
                val bytes = readLimited(app, uri)
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
        val app = getApplication<Application>()
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            val chars = password.toCharArray()
            try {
                val bytes = readLimited(app, uri)
                val result = AegisImporter.import(bytes, chars)
                val current = vault.currentData() ?: error("Vault is locked")
                val data = current
                val existingSecrets = data.items
                    .mapNotNull { it.totp?.secret }
                    .toMutableSet()
                val uniqueItems = result.items.filter { item ->
                    item.totp?.secret?.let { existingSecrets.add(it) } ?: true
                }
                val skippedDuplicates = result.items.size - uniqueItems.size
                val groups = data.groups.toMutableList()
                val groupIdMap = mutableMapOf<String, String>()
                result.groups.forEach { importedGroup ->
                    val existing = groups.firstOrNull {
                        it.name.equals(importedGroup.name, ignoreCase = true)
                    }
                    val target = existing ?: importedGroup.copy(id = UUID.randomUUID().toString())
                        .also { groups.add(it) }
                    groupIdMap[importedGroup.id] = target.id
                }
                val importedItems = uniqueItems.map { item ->
                    item.copy(
                        groupIds = item.groupIds.mapNotNull { groupIdMap[it] },
                    )
                }
                val merged = data.copy(
                    groups = groups,
                    items = data.items + importedItems,
                )
                val sealedBytes = vault.persist(merged)
                autoBackupIfConfigured(sealedBytes)
                _state.update {
                    it.copy(
                        data = merged,
                        busy = false,
                        error = null,
                        message = if (skippedDuplicates > 0) {
                            "已导入 ${importedItems.size} 个条目（跳过 $skippedDuplicates 个重复）"
                        } else {
                            "已导入 ${importedItems.size} 个条目"
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

    private fun loadSettings(): AppSettings {
        val accent = prefs.getInt(KEY_ACCENT, 0).coerceIn(0, 4)
        val custom = if (prefs.contains(KEY_CUSTOM)) prefs.getInt(KEY_CUSTOM, 0) else null
        val dark = runCatching {
            DarkMode.valueOf(prefs.getString(KEY_DARK, DarkMode.SYSTEM.name)!!)
        }.getOrDefault(DarkMode.SYSTEM)
        return AppSettings(
            accentIndex = accent,
            customAccent = custom,
            darkMode = dark,
            showTokenCodes = prefs.getBoolean(KEY_SHOW_CODES, true),
            showNextToken = prefs.getBoolean(KEY_NEXT_TOKEN, false),
            secureScreen = prefs.getBoolean(KEY_SECURE_SCREEN, false),
            autoLockSeconds = prefs.getInt(KEY_AUTO_LOCK, 0),
            codeGrouping = runCatching {
                CodeGrouping.valueOf(
                    prefs.getString(KEY_CODE_GROUPING, CodeGrouping.AUTO.name)!!,
                )
            }.getOrDefault(CodeGrouping.AUTO),
            autoBackup = prefs.getBoolean(KEY_AUTO_BACKUP, false),
            backupTreeUri = prefs.getString(KEY_BACKUP_TREE, "").orEmpty(),
            backupFolderName = prefs.getString(KEY_BACKUP_NAME, "").orEmpty(),
            lastBackupAt = prefs.getLong(KEY_LAST_BACKUP, 0L),
        )
    }

    private fun autoBackupIfConfigured(bytes: ByteArray) {
        val settings = _settings.value
        if (!settings.autoBackup || settings.backupTreeUri.isBlank()) return
        runCatching { writeBackup(bytes) }
    }

    private fun readLimited(
        context: Context,
        uri: Uri,
        maxBytes: Int = MAX_IMPORT_BYTES,
    ): ByteArray {
        val input = context.contentResolver.openInputStream(uri)
            ?: error("无法读取文件")
        return input.use { stream ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            var total = 0
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                total += read
                if (total > maxBytes) {
                    error("文件过大（上限 ${maxBytes / (1024 * 1024)} MB）")
                }
                out.write(buffer, 0, read)
            }
            out.toByteArray()
        }
    }

    private fun writeBackup(bytes: ByteArray) {
        val current = _settings.value
        if (current.backupTreeUri.isBlank()) error("请先选择备份目录")
        AutoBackupManager.write(
            context = getApplication(),
            treeUri = current.backupTreeUri,
            bytes = bytes,
        )
        val now = System.currentTimeMillis()
        _settings.update { it.copy(lastBackupAt = now) }
        prefs.edit().putLong(KEY_LAST_BACKUP, now).apply()
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

    companion object {
        private const val MAX_IMPORT_BYTES = 64 * 1024 * 1024
        private const val KEY_ACCENT = "accent"
        private const val KEY_CUSTOM = "customAccent"
        private const val KEY_DARK = "dark"
        private const val KEY_SHOW_CODES = "showTokenCodes"
        private const val KEY_NEXT_TOKEN = "showNextToken"
        private const val KEY_SECURE_SCREEN = "secureScreen"
        private const val KEY_AUTO_LOCK = "autoLockSeconds"
        private const val KEY_CODE_GROUPING = "codeGrouping"
        private const val KEY_AUTO_BACKUP = "autoBackup"
        private const val KEY_BACKUP_TREE = "backupTreeUri"
        private const val KEY_BACKUP_NAME = "backupFolderName"
        private const val KEY_LAST_BACKUP = "lastBackupAt"
    }
}
