package top.talyra42.keycase.data

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
