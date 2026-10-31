package top.talyra42.keycase.ui

import androidx.compose.ui.res.stringResource

import top.talyra42.keycase.R

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.DarkMode
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.Fingerprint
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Save
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.UploadFile
import androidx.compose.material.icons.outlined.VpnKey
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.data.AutoBackupManager
import top.talyra42.keycase.data.UpdateChecker
import top.talyra42.keycase.ui.icons.ImportedIconPack
import top.talyra42.keycase.ui.theme.AccentNames
import top.talyra42.keycase.ui.theme.AccentPalette
import top.talyra42.keycase.ui.theme.onAccent

@Composable
fun SettingsScreen(
    data: VaultData,
    settings: AppSettings,
    onLock: () -> Unit,
    onAccent: (Int) -> Unit,
    onDarkMode: (DarkMode) -> Unit,
    onExport: (Uri) -> Unit,
    onImport: (Uri, String) -> Unit,
    onImportAegis: (Uri, String) -> Unit,
    onImportGoogle: (String) -> Unit,
    onPrepareExternal: () -> Unit,
    onCustomAccent: (Int) -> Unit,
    onShowTokenCodes: (Boolean) -> Unit,
    onShowNextToken: (Boolean) -> Unit,
    onCodeGrouping: (CodeGrouping) -> Unit,
    onSecureScreen: (Boolean) -> Unit,
    onAutoLock: (Int) -> Unit,
    onAutoBackup: (Boolean) -> Unit,
    onBackupFolder: (String, String) -> Unit,
    onBackupNow: () -> Unit,
    onOpenSecurity: () -> Unit,
    onOpenTrash: () -> Unit,
    biometricAvailable: Boolean,
    biometricEnrolled: Boolean,
    onEnableBiometric: () -> Unit,
    onDisableBiometric: () -> Unit,
    onChangePassword: (String, String, String) -> Unit,
    onDeleteVault: () -> Unit,
) {
    val exportLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/octet-stream"),
    ) { uri -> if (uri != null) onExport(uri) }
    var pendingImport by remember { mutableStateOf<Uri?>(null) }
    var pendingAegis by remember { mutableStateOf<Uri?>(null) }
    val importLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri -> if (uri != null) pendingImport = uri }
    val aegisLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri -> if (uri != null) pendingAegis = uri }
    val context = LocalContext.current
    val versionName = remember(context) {
        runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        }.getOrNull() ?: "0.0.0"
    }
    var checkingUpdate by remember { mutableStateOf(false) }
    var updateInfo by remember { mutableStateOf<UpdateChecker.Update?>(null) }
    var updateError by remember { mutableStateOf(false) }
    val backupFolderLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocumentTree(),
    ) { uri ->
        if (uri != null) {
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
            }
            val name = AutoBackupManager.displayName(context, uri.toString()) ?: "已选择"
            onBackupFolder(uri.toString(), name)
        }
    }
    val scope = rememberCoroutineScope()
    var iconPackStatus by remember { mutableStateOf<String?>(null) }
    val iconPackLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent(),
    ) { uri ->
        if (uri != null) {
            scope.launch {
                withContext(Dispatchers.IO) {
                    runCatching { ImportedIconPack.import(context, uri) }
                }.onSuccess { result ->
                    iconPackStatus = "已导入 ${result.imported} 个图标"
                }.onFailure {
                    iconPackStatus = it.message ?: "无法读取图标包"
                }
            }
        }
    }
    var showPassword by remember { mutableStateOf(false) }
    var showCustomAccent by remember { mutableStateOf(false) }
    var showGoogleImport by remember { mutableStateOf(false) }
    var showIconPreview by remember { mutableStateOf(false) }
    var showAutoLock by remember { mutableStateOf(false) }
    var showCodeGrouping by remember { mutableStateOf(false) }
    var showDeleteVault by remember { mutableStateOf(false) }

    fun checkUpdates() {
        if (checkingUpdate) return
        checkingUpdate = true
        scope.launch {
            val result = runCatching { UpdateChecker.check(versionName) }
            checkingUpdate = false
            result
                .onSuccess { updateInfo = it }
                .onFailure { updateError = true }
        }
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = 16.dp,
            end = 16.dp,
            top = 16.dp,
            bottom = 32.dp,
        ),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item {
            Text(
                text = stringResource(R.string.s_7debf9cb0372),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "${data.items.count { it.deletedAt == null }} 个条目 · 本地加密",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        item {
            SettingsLabel("外观")
            AppCard {
                AccentSetting(
                    selectedIndex = settings.accentIndex,
                    customAccent = settings.customAccent,
                    onAccent = onAccent,
                    onCustomClick = { showCustomAccent = true },
                )
                SettingsDivider()
                ThemeSetting(settings.darkMode, onDarkMode)
            }
        }

        item {
            SettingsLabel("图标")
            AppCard {
                ActionRow(
                    icon = Icons.Outlined.UploadFile,
                    title = "导入图标包",
                    subtitle = iconPackStatus ?: "从 Aegis ZIP 导入 PNG 图标",
                    onClick = {
                        onPrepareExternal()
                        iconPackLauncher.launch("*/*")
                    },
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Palette,
                    title = "预览图标包",
                    subtitle = "查看内置与已导入图标",
                    onClick = { showIconPreview = true },
                )
            }
        }

        item {
            SettingsLabel("数据")
            AppCard {
                ActionRow(
                    icon = Icons.Outlined.Download,
                    title = "导出加密备份",
                    subtitle = "使用当前主密码加密的 .tkv 文件",
                    onClick = {
                        onPrepareExternal()
                        exportLauncher.launch("keycase-backup.tkv")
                    },
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.UploadFile,
                    title = "导入加密备份",
                    subtitle = "替换当前保险库",
                    onClick = {
                        onPrepareExternal()
                        importLauncher.launch(arrayOf("application/octet-stream", "application/zip"))
                    },
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Folder,
                    title = "从 Aegis 导入",
                    subtitle = "合并 TOTP 条目",
                    onClick = {
                        onPrepareExternal()
                        aegisLauncher.launch(arrayOf("application/json", "text/plain", "*/*"))
                    },
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.FileDownload,
                    title = "从 Google Authenticator 导入",
                    subtitle = "迁移链接或迁移二维码",
                    onClick = { showGoogleImport = true },
                )
            }
        }

        item {
            SettingsLabel("备份")
            AppCard {
                SwitchRow(
                    title = "自动备份",
                    subtitle = if (settings.backupTreeUri.isBlank()) {
                        "选择目录后，每次保存自动生成加密快照"
                    } else {
                        "每次保存后备份到 ${settings.backupFolderName.ifBlank { "所选目录" }}"
                    },
                    checked = settings.autoBackup,
                    onCheckedChange = { enabled ->
                        if (enabled && settings.backupTreeUri.isBlank()) {
                            onPrepareExternal()
                            backupFolderLauncher.launch(null)
                        } else {
                            onAutoBackup(enabled)
                        }
                    },
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Folder,
                    title = "备份目录",
                    subtitle = settings.backupFolderName.ifBlank { "未选择，点击选择 Documents 等目录" },
                    onClick = {
                        onPrepareExternal()
                        backupFolderLauncher.launch(null)
                    },
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Schedule,
                    title = "上次备份",
                    subtitle = if (settings.lastBackupAt == 0L) {
                        "尚未备份"
                    } else {
                        java.text.SimpleDateFormat("MM-dd HH:mm", java.util.Locale.getDefault())
                            .format(java.util.Date(settings.lastBackupAt))
                    },
                    onClick = null,
                    trailingChevron = false,
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Save,
                    title = "立即备份",
                    subtitle = "生成一份加密快照，保留最近 10 份",
                    onClick = onBackupNow,
                )
            }
        }

        item {
            SettingsLabel("整理")
            AppCard {
                ActionRow(
                    icon = Icons.Outlined.Delete,
                    title = "回收站",
                    subtitle = "${data.items.count { it.deletedAt != null }} 个已删除条目",
                    onClick = onOpenTrash,
                )
            }
        }

        item {
            SettingsLabel("令牌")
            AppCard {
                SwitchRow(
                    title = "显示验证码",
                    subtitle = "关闭后数字显示为圆点，点击可查看并复制",
                    checked = settings.showTokenCodes,
                    onCheckedChange = onShowTokenCodes,
                )
                SettingsDivider()
                SwitchRow(
                    title = "提前显示下一组",
                    subtitle = "在当前验证码下方显示下一组",
                    checked = settings.showNextToken,
                    onCheckedChange = onShowNextToken,
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Schedule,
                    title = "验证码分组",
                    subtitle = when (settings.codeGrouping) {
                        CodeGrouping.AUTO -> "自动 · 6 位按 3+3，8 位按 4+4"
                        CodeGrouping.THREE -> "每 3 位分隔"
                        CodeGrouping.FOUR -> "每 4 位分隔"
                        CodeGrouping.NONE -> "不分隔"
                    },
                    onClick = { showCodeGrouping = true },
                )
            }
        }

        item {
            SettingsLabel("安全")
            AppCard {
                SwitchRow(
                    title = "防止截屏",
                    subtitle = "禁止系统截图和录屏",
                    checked = settings.secureScreen,
                    onCheckedChange = onSecureScreen,
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Lock,
                    title = "自动锁定",
                    subtitle = when (settings.autoLockSeconds) {
                        0 -> "退到后台立即锁定"
                        30 -> "退到后台 30 秒后锁定"
                        60 -> "退到后台 1 分钟后锁定"
                        else -> "退到后台 5 分钟后锁定"
                    },
                    onClick = { showAutoLock = true },
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Fingerprint,
                    title = "生物识别解锁",
                    subtitle = when {
                        !biometricAvailable -> "设备不支持"
                        biometricEnrolled -> "已启用，点击关闭"
                        else -> "使用指纹解锁保险库"
                    },
                    onClick = {
                        if (biometricAvailable) {
                            if (biometricEnrolled) onDisableBiometric() else onEnableBiometric()
                        }
                    },
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Shield,
                    title = "安全中心",
                    subtitle = "${securityIssues(data.items.filter { it.deletedAt == null && it.kind == top.talyra42.keycase.core.model.ItemKind.LOGIN }).size} 个条目待处理",
                    onClick = onOpenSecurity,
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Lock,
                    title = "修改主密码",
                    subtitle = "旧密码立即失效",
                    onClick = { showPassword = true },
                )
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Lock,
                    title = "立即锁定",
                    subtitle = "清除内存中的密钥",
                    onClick = onLock,
                )
            }
        }

        item {
            SettingsLabel("关于")
            AppCard {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .background(
                                MaterialTheme.colorScheme.primaryContainer,
                                RoundedCornerShape(9.dp),
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Outlined.VpnKey,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(17.dp),
                        )
                    }
                    Spacer(Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "KeyCase",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                        )
                        Text(
                            text = "版本 $versionName · GPL-3.0-or-later",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                SettingsDivider()
                ActionRow(
                    icon = Icons.Outlined.Refresh,
                    title = "检查更新",
                    subtitle = if (checkingUpdate) "正在检查…" else "当前版本 v$versionName",
                    onClick = { checkUpdates() },
                )
            }
        }

        item {
            SettingsLabel("危险")
            AppCard {
                ActionRow(
                    icon = Icons.Outlined.Delete,
                    title = "删除保险库",
                    subtitle = "永久删除本机所有密码和令牌",
                    onClick = { showDeleteVault = true },
                )
            }
        }
    }

    updateInfo?.let { update ->
        AlertDialog(
            onDismissRequest = { updateInfo = null },
            title = {
                Text(if (update.available) "发现新版本" else "检查更新")
            },
            text = {
                Text(
                    if (update.available) {
                        "新版本 v${update.latestVersion} 已发布，当前版本 v$versionName。"
                    } else {
                        "当前已是最新版本 v$versionName。"
                    },
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (update.available) {
                            runCatching {
                                context.startActivity(
                                    Intent(Intent.ACTION_VIEW, Uri.parse(update.releaseUrl)),
                                )
                            }
                        }
                        updateInfo = null
                    },
                ) {
                    Text(if (update.available) "去更新" else "好")
                }
            },
            dismissButton = if (update.available) {
                {
                    TextButton(onClick = { updateInfo = null }) { Text(stringResource(R.string.s_479fcc1cc066)) }
                }
            } else {
                null
            },
        )
    }
    if (updateError) {
        AlertDialog(
            onDismissRequest = { updateError = false },
            title = { Text(stringResource(R.string.s_c76c74e8094b)) },
            text = { Text(stringResource(R.string.s_51e9b77a7720)) },
            confirmButton = {
                TextButton(onClick = { updateError = false }) { Text(stringResource(R.string.s_27e4fe4c3fe2)) }
            },
        )
    }
    if (showPassword) {
        ChangeMasterPasswordDialog(
            onDismiss = { showPassword = false },
            onSubmit = onChangePassword,
        )
    }
    pendingImport?.let { uri ->
        ImportBackupDialog(
            onDismiss = { pendingImport = null },
            onSubmit = { password ->
                onImport(uri, password)
                pendingImport = null
            },
        )
    }
    pendingAegis?.let { uri ->
        ImportAegisDialog(
            onDismiss = { pendingAegis = null },
            onSubmit = { password ->
                onImportAegis(uri, password)
                pendingAegis = null
            },
        )
    }
    if (showCustomAccent) {
        CustomAccentDialog(
            initial = settings.customAccent,
            onDismiss = { showCustomAccent = false },
            onSubmit = {
                onCustomAccent(it)
                showCustomAccent = false
            },
        )
    }
    if (showIconPreview) {
        IconPackPreviewDialog(onDismiss = { showIconPreview = false })
    }
    if (showAutoLock) {
        AlertDialog(
            onDismissRequest = { showAutoLock = false },
            title = { Text(stringResource(R.string.s_4553a16a3a0b)) },
            text = {
                Column {
                    listOf(
                        0 to "立即",
                        30 to "30 秒",
                        60 to "1 分钟",
                        300 to "5 分钟",
                    ).forEach { (seconds, label) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    onAutoLock(seconds)
                                    showAutoLock = false
                                }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            RadioButton(
                                selected = settings.autoLockSeconds == seconds,
                                onClick = {
                                    onAutoLock(seconds)
                                    showAutoLock = false
                                },
                            )
                            Text(label)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showAutoLock = false }) { Text(stringResource(R.string.s_4d0b4688c787)) }
            },
        )
    }
    if (showCodeGrouping) {
        AlertDialog(
            onDismissRequest = { showCodeGrouping = false },
            title = { Text(stringResource(R.string.s_8276e61c0585)) },
            text = {
                Column {
                    listOf(
                        CodeGrouping.AUTO to "自动（6 位 3+3，8 位 4+4）",
                        CodeGrouping.THREE to "每 3 位",
                        CodeGrouping.FOUR to "每 4 位",
                        CodeGrouping.NONE to "不分隔",
                    ).forEach { (mode, label) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    onCodeGrouping(mode)
                                    showCodeGrouping = false
                                }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            RadioButton(
                                selected = settings.codeGrouping == mode,
                                onClick = {
                                    onCodeGrouping(mode)
                                    showCodeGrouping = false
                                },
                            )
                            Text(label)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showCodeGrouping = false }) { Text(stringResource(R.string.s_4d0b4688c787)) }
            },
        )
    }
    if (showGoogleImport) {
        GoogleMigrationImportDialog(
            onDismiss = { showGoogleImport = false },
            onImport = {
                onImportGoogle(it)
                showGoogleImport = false
            },
        )
    }
    if (showDeleteVault) {
        ConfirmDialog(
            title = "删除保险库？",
            text = "所有密码和令牌将被永久删除，无法恢复。",
            confirmLabel = "删除保险库",
            onConfirm = {
                showDeleteVault = false
                onDeleteVault()
            },
            onDismiss = { showDeleteVault = false },
        )
    }
}

@Composable
private fun SettingsLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 4.dp, bottom = 10.dp),
    )
}

@Composable
private fun AccentSetting(
    selectedIndex: Int,
    customAccent: Int?,
    onAccent: (Int) -> Unit,
    onCustomClick: () -> Unit,
) {
    Column(modifier = Modifier.padding(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Outlined.Palette,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.s_6f67371e0527), style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
            Text(
                if (customAccent != null) "自定义" else AccentNames[selectedIndex.coerceIn(0, AccentNames.lastIndex)],
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.height(10.dp))
        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AccentPalette.forEachIndexed { index, color ->
                val selected = customAccent == null && selectedIndex == index
                val label = localized(AccentNames[index])
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .selectable(
                            selected = selected,
                            role = Role.RadioButton,
                            onClick = { onAccent(index) },
                        )
                        .semantics { contentDescription = label },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .border(
                                width = if (selected) 2.dp else 0.dp,
                                color = MaterialTheme.colorScheme.onSurface,
                                shape = CircleShape,
                            )
                            .padding(2.dp)
                            .background(color, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (selected) {
                            Icon(
                                Icons.Outlined.Check,
                                contentDescription = null,
                                tint = onAccent(color),
                                modifier = Modifier.size(14.dp),
                            )
                        }
                    }
                }
            }
            if (customAccent != null) {
                val customLabel = localized("自定义颜色")
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .semantics { contentDescription = customLabel },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .size(28.dp)
                            .border(2.dp, MaterialTheme.colorScheme.onSurface, CircleShape)
                            .padding(2.dp)
                            .background(Color(customAccent), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Outlined.Check,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.size(14.dp),
                        )
                    }
                }
            }
            IconButton(
                onClick = onCustomClick,
                modifier = Modifier.size(32.dp),
            ) {
                Icon(
                    Icons.Outlined.Palette,
                    contentDescription = stringResource(R.string.s_367808b1d149),
                    modifier = Modifier.size(18.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ThemeSetting(mode: DarkMode, onDarkMode: (DarkMode) -> Unit) {
    Column(modifier = Modifier.padding(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Outlined.DarkMode,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.s_4a8bb8aba399), style = MaterialTheme.typography.titleSmall)
        }
        Spacer(Modifier.height(10.dp))
        val modes = listOf(
            DarkMode.SYSTEM to "系统",
            DarkMode.LIGHT to "浅色",
            DarkMode.DARK to "深色",
        )
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            modes.forEachIndexed { index, (value, label) ->
                SegmentedButton(
                    selected = mode == value,
                    onClick = { onDarkMode(value) },
                    shape = SegmentedButtonDefaults.itemShape(index = index, count = modes.size),
                    icon = {},
                    label = { Text(label, style = MaterialTheme.typography.labelMedium) },
                )
            }
        }
    }
}

@Composable
private fun ActionRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: (() -> Unit)? = null,
    trailingChevron: Boolean = true,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = onClick != null) { onClick?.invoke() }
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(9.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(17.dp),
            )
        }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            Text(
                subtitle,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (trailingChevron) {
            Icon(
                Icons.Outlined.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
private fun SwitchRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .toggleable(
                value = checked,
                role = Role.Switch,
                onValueChange = onCheckedChange,
            )
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            Text(
                subtitle,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = null,
            colors = SwitchDefaults.colors(
                checkedThumbColor = MaterialTheme.colorScheme.onPrimary,
                checkedTrackColor = MaterialTheme.colorScheme.primary,
                checkedBorderColor = MaterialTheme.colorScheme.primary,
                uncheckedThumbColor = MaterialTheme.colorScheme.outline,
                uncheckedTrackColor = MaterialTheme.colorScheme.surfaceVariant,
                uncheckedBorderColor = MaterialTheme.colorScheme.outline,
            ),
        )
    }
}

@Composable
private fun InfoLine(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f),
        )
        Text(
            value,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun SettingsDivider() {
    HorizontalDivider(
        color = MaterialTheme.colorScheme.outlineVariant,
    )
}
