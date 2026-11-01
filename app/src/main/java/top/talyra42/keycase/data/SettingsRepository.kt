package top.talyra42.keycase.data

import android.content.Context

/**
 * Non-secret UI preferences. The vault key, master password and TOTP secrets
 * never live here.
 */
class SettingsRepository(context: Context) {
    private val prefs = context.getSharedPreferences("keycase.settings.v2", Context.MODE_PRIVATE)

    fun load(): AppSettings {
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
            autoLockSeconds = prefs.getInt(KEY_AUTO_LOCK, 0).coerceIn(0, 300),
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

    fun save(settings: AppSettings) {
        prefs.edit()
            .putInt(KEY_ACCENT, settings.accentIndex)
            .apply {
                if (settings.customAccent == null) remove(KEY_CUSTOM)
                else putInt(KEY_CUSTOM, settings.customAccent)
            }
            .putString(KEY_DARK, settings.darkMode.name)
            .putBoolean(KEY_SHOW_CODES, settings.showTokenCodes)
            .putBoolean(KEY_NEXT_TOKEN, settings.showNextToken)
            .putBoolean(KEY_SECURE_SCREEN, settings.secureScreen)
            .putInt(KEY_AUTO_LOCK, settings.autoLockSeconds)
            .putString(KEY_CODE_GROUPING, settings.codeGrouping.name)
            .putBoolean(KEY_AUTO_BACKUP, settings.autoBackup)
            .putString(KEY_BACKUP_TREE, settings.backupTreeUri)
            .putString(KEY_BACKUP_NAME, settings.backupFolderName)
            .putLong(KEY_LAST_BACKUP, settings.lastBackupAt)
            .apply()
    }

    private companion object {
        const val KEY_ACCENT = "accent"
        const val KEY_CUSTOM = "customAccent"
        const val KEY_DARK = "dark"
        const val KEY_SHOW_CODES = "showTokenCodes"
        const val KEY_NEXT_TOKEN = "showNextToken"
        const val KEY_SECURE_SCREEN = "secureScreen"
        const val KEY_AUTO_LOCK = "autoLockSeconds"
        const val KEY_CODE_GROUPING = "codeGrouping"
        const val KEY_AUTO_BACKUP = "autoBackup"
        const val KEY_BACKUP_TREE = "backupTreeUri"
        const val KEY_BACKUP_NAME = "backupFolderName"
        const val KEY_LAST_BACKUP = "lastBackupAt"
    }
}
