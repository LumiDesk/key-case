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
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import top.talyra42.keycase.core.crypto.KdfParams
import top.talyra42.keycase.core.importing.AegisImporter
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.TotpSecret
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.model.VaultGroup
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.core.otp.GoogleMigrationParser
import top.talyra42.keycase.core.vault.UnlockedVault
import top.talyra42.keycase.core.vault.VaultContainer
import top.talyra42.keycase.data.AndroidVaultStore
import java.time.Instant
import java.util.UUID

enum class DarkMode { SYSTEM, LIGHT, DARK }

data class AppSettings(
    val accentIndex: Int = 0,
    val customAccent: Int? = null,
    val darkMode: DarkMode = DarkMode.SYSTEM,
)

data class UiState(
    val vaultExists: Boolean = false,
    val locked: Boolean = true,
    val data: VaultData? = null,
    val busy: Boolean = false,
    val error: String? = null,
)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val store = AndroidVaultStore(application)
    private val prefs = application.getSharedPreferences("keycase.settings.v2", Context.MODE_PRIVATE)
    private val saveMutex = Mutex()

    private val _state = MutableStateFlow(
        UiState(vaultExists = store.exists(), locked = true),
    )
    val state = _state.asStateFlow()

    private val _settings = MutableStateFlow(loadSettings())
    val settings = _settings.asStateFlow()

    private var session: UnlockedVault? = null
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
                val created = VaultContainer.createSession(chars, empty, KdfParams())
                store.write(created.bytes)
                session = created.session
                _state.update {
                    it.copy(
                        vaultExists = true,
                        locked = false,
                        data = session?.data,
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
        if (!store.exists()) {
            _state.update { it.copy(vaultExists = false, locked = true) }
            return
        }

        runVaultOperation {
            val chars = password.toCharArray()
            try {
                val bytes = store.read()
                session = VaultContainer.unlock(chars, bytes)
                _state.update {
                    it.copy(
                        vaultExists = true,
                        locked = false,
                        data = session?.data,
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
        session?.close()
        session = null
        _state.update {
            it.copy(locked = true, data = null, busy = false)
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

    fun onHostStopped() {
        if (keepUnlockedForExternal) {
            keepUnlockedForExternal = false
        } else {
            lock()
        }
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

    fun deleteItem(itemId: String) {
        val data = _state.value.data ?: return
        persist(data.copy(items = data.items.filterNot { it.id == itemId }))
    }

    fun addGroup(name: String) {
        val data = _state.value.data ?: return
        val clean = name.trim()
        if (clean.isBlank()) {
            _state.update { it.copy(error = "分组名不能为空") }
            return
        }
        if (data.groups.any { it.name.equals(clean, ignoreCase = true) }) {
            _state.update { it.copy(error = "分组已存在") }
            return
        }
        val group = VaultGroup(
            id = UUID.randomUUID().toString(),
            name = clean,
            order = data.groups.size,
        )
        persist(data.copy(groups = data.groups + group))
    }

    fun renameGroup(groupId: String, name: String) {
        val data = _state.value.data ?: return
        val clean = name.trim()
        if (clean.isBlank()) {
            _state.update { it.copy(error = "分组名不能为空") }
            return
        }
        if (data.groups.any { it.id != groupId && it.name.equals(clean, ignoreCase = true) }) {
            _state.update { it.copy(error = "分组已存在") }
            return
        }
        persist(
            data.copy(
                groups = data.groups.map {
                    if (it.id == groupId) it.copy(name = clean) else it
                },
            ),
        )
    }

    fun deleteGroup(groupId: String) {
        val data = _state.value.data ?: return
        persist(
            data.copy(
                groups = data.groups.filterNot { it.id == groupId },
                items = data.items.map {
                    if (groupId in it.groupIds) {
                        it.copy(groupIds = it.groupIds - groupId)
                    } else {
                        it
                    }
                },
            ),
        )
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
                val unlocked = session ?: error("Vault is locked")
                val onDisk = store.read()
                // Verify the current password against the on-disk slot before
                // rotating it; the in-memory session alone cannot prove it.
                VaultContainer.unlock(currentChars, onDisk).close()
                val rotated = VaultContainer.changePasswordSession(unlocked, newChars, KdfParams())
                store.write(rotated.bytes)
                session?.close()
                session = rotated.session
                _state.update {
                    it.copy(
                        data = rotated.session.data,
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
                val current = session ?: error("Vault is locked")
                val now = Instant.now().toString()
                val items = parsed.map { otp ->
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
                val next = current.withData(
                    current.data.copy(items = current.data.items + items),
                )
                store.write(VaultContainer.seal(next))
                session = next
                _state.update {
                    it.copy(data = next.data, busy = false, error = null)
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

    fun exportBackup(uri: Uri) {
        val app = getApplication<Application>()
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            try {
                app.contentResolver.openOutputStream(uri)?.use { out ->
                    out.write(store.read())
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
                val bytes = app.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: error("无法读取备份文件")
                val imported = VaultContainer.unlock(chars, bytes)
                store.write(bytes)
                session?.close()
                session = imported
                _state.update {
                    it.copy(
                        vaultExists = true,
                        locked = false,
                        data = imported.data,
                        busy = false,
                        error = null,
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

    fun importAegis(uri: Uri, password: String) {        val app = getApplication<Application>()
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            val chars = password.toCharArray()
            try {
                val bytes = app.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: error("无法读取 Aegis 文件")
                val result = AegisImporter.import(bytes, chars)
                val current = session ?: error("Vault is locked")
                val data = current.data
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
                val importedItems = result.items.map { item ->
                    item.copy(
                        groupIds = item.groupIds.mapNotNull { groupIdMap[it] },
                    )
                }
                val merged = data.copy(
                    groups = groups,
                    items = data.items + importedItems,
                )
                val next = current.withData(merged)
                store.write(VaultContainer.seal(next))
                session = next
                _state.update {
                    it.copy(
                        data = next.data,
                        busy = false,
                        error = null,
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
        session?.close()
        session = null
        super.onCleared()
    }

    private fun loadSettings(): AppSettings {
        val accent = prefs.getInt(KEY_ACCENT, 0).coerceIn(0, 4)
        val custom = if (prefs.contains(KEY_CUSTOM)) prefs.getInt(KEY_CUSTOM, 0) else null
        val dark = runCatching {
            DarkMode.valueOf(prefs.getString(KEY_DARK, DarkMode.SYSTEM.name)!!)
        }.getOrDefault(DarkMode.SYSTEM)
        return AppSettings(accent, custom, dark)
    }

    private fun persist(data: VaultData) {
        viewModelScope.launch(Dispatchers.IO) {
            _state.update { it.copy(busy = true, error = null) }
            try {
                saveMutex.withLock {
                    val current = session ?: error("Vault is locked")
                    val next = current.withData(data)
                    val bytes = VaultContainer.seal(next)
                    store.write(bytes)
                    session = next
                    _state.update {
                        it.copy(data = next.data, busy = false, error = null)
                    }
                }
            } catch (e: Exception) {
                _state.update {
                    it.copy(busy = false, error = e.message ?: "保存失败")
                }
            }
        }
    }

    private fun runVaultOperation(block: () -> Unit) {
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
        private const val KEY_ACCENT = "accent"
        private const val KEY_CUSTOM = "customAccent"
        private const val KEY_DARK = "dark"
    }
}
