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
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.TotpSecret
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.model.VaultGroup
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.core.vault.UnlockedVault
import top.talyra42.keycase.core.vault.VaultContainer
import top.talyra42.keycase.data.AndroidVaultStore
import java.time.Instant
import java.util.UUID

enum class DarkMode { SYSTEM, LIGHT, DARK }

data class AppSettings(
    val accentIndex: Int = 0,
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
    private val prefs = application.getSharedPreferences("keycase.settings", Context.MODE_PRIVATE)
    private val saveMutex = Mutex()

    private val _state = MutableStateFlow(
        UiState(vaultExists = store.exists(), locked = true),
    )
    val state = _state.asStateFlow()

    private val _settings = MutableStateFlow(loadSettings())
    val settings = _settings.asStateFlow()

    private var session: UnlockedVault? = null

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

    fun clearError() {
        _state.update { it.copy(error = null) }
    }

    fun setAccent(index: Int) {
        val safe = index.coerceIn(0, 4)
        _settings.update { it.copy(accentIndex = safe) }
        prefs.edit().putInt(KEY_ACCENT, safe).apply()
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

    override fun onCleared() {
        session?.close()
        session = null
        super.onCleared()
    }

    private fun loadSettings(): AppSettings {
        val accent = prefs.getInt(KEY_ACCENT, 0).coerceIn(0, 4)
        val dark = runCatching {
            DarkMode.valueOf(prefs.getString(KEY_DARK, DarkMode.SYSTEM.name)!!)
        }.getOrDefault(DarkMode.SYSTEM)
        return AppSettings(accent, dark)
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
        private const val KEY_DARK = "dark"
    }
}
