package top.talyra42.keycase.ui

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.UploadFile
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.ui.theme.AccentNames
import top.talyra42.keycase.ui.theme.AccentPalette

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
    onAddGroup: (String) -> Unit,
    onRenameGroup: (String, String) -> Unit,
    onDeleteGroup: (String) -> Unit,
    onChangePassword: (String, String, String) -> Unit,
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
    var showGroups by remember { mutableStateOf(false) }
    var showPassword by remember { mutableStateOf(false) }
    var showCustomAccent by remember { mutableStateOf(false) }
    var showGoogleImport by remember { mutableStateOf(false) }
    val itemCounts = remember(data.items) {
        data.groups.associate { group ->
            group.id to data.items.count { group.id in it.groupIds }
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
                text = "设置",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "${data.items.size} 个条目 · 本地加密",
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
                    subtitle = "合并 TOTP 条目与分组",
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
            SettingsLabel("整理")
            AppCard {
                ActionRow(
                    icon = Icons.Outlined.Folder,
                    title = "分组",
                    subtitle = "${data.groups.size} 个分组",
                    onClick = { showGroups = true },
                )
            }
        }

        item {
            SettingsLabel("安全")
            AppCard {
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
                InfoLine("版本", "0.1.0")
                SettingsDivider()
                InfoLine("许可证", "GPL-3.0-or-later")
                SettingsDivider()
                Row(
                    modifier = Modifier.padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Outlined.Shield,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(17.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = "KeyCase · 本地优先的密码与动态令牌管理器",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }

    if (showGroups) {
        GroupManagerDialog(
            groups = data.groups,
            itemCounts = itemCounts,
            onAdd = onAddGroup,
            onRename = onRenameGroup,
            onDelete = onDeleteGroup,
            onDismiss = { showGroups = false },
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
    if (showGoogleImport) {
        GoogleMigrationImportDialog(
            onDismiss = { showGoogleImport = false },
            onImport = {
                onImportGoogle(it)
                showGoogleImport = false
            },
        )
    }
}

@Composable
private fun SettingsLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 4.dp, bottom = 2.dp),
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
            Text("强调色", style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
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
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .border(
                            width = if (selected) 2.dp else 0.dp,
                            color = MaterialTheme.colorScheme.onSurface,
                            shape = CircleShape,
                        )
                        .padding(2.dp)
                        .background(color, CircleShape)
                        .clickable { onAccent(index) },
                    contentAlignment = Alignment.Center,
                ) {
                    if (selected) {
                        Icon(
                            Icons.Outlined.Check,
                            contentDescription = "已选择",
                            tint = if (color == AccentPalette[3]) Color.Black else Color.White,
                            modifier = Modifier.size(14.dp),
                        )
                    }
                }
            }
            if (customAccent != null) {
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
                        contentDescription = "自定义颜色",
                        tint = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.size(14.dp),
                    )
                }
            }
            IconButton(
                onClick = onCustomClick,
                modifier = Modifier.size(32.dp),
            ) {
                Icon(
                    Icons.Outlined.Palette,
                    contentDescription = "打开取色板",
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
            Text("显示模式", style = MaterialTheme.typography.titleSmall)
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
                    icon = {
                        SegmentedButtonDefaults.Icon(active = mode == value, inactiveContent = {})
                    },
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
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
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
        Icon(
            Icons.Outlined.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(18.dp),
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
        modifier = Modifier.padding(start = 54.dp),
        color = MaterialTheme.colorScheme.outlineVariant,
    )
}
