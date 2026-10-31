package top.talyra42.keycase.ui

import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.VpnKey
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.ui.theme.KeyCaseTheme

sealed interface Route {
    data object Main : Route
    data class Detail(val itemId: String) : Route
    data class PasswordEditor(val itemId: String?) : Route
    data class TokenEditor(val itemId: String?, val initialUri: String? = null) : Route
}

@Composable
fun KeyCaseApp(viewModel: MainViewModel) {
    val state by viewModel.state.collectAsState()
    val settings by viewModel.settings.collectAsState()

    KeyCaseTheme(settings) {
        Surface(modifier = Modifier.fillMaxSize()) {
            when {
                !state.vaultExists -> CreateVaultScreen(
                    busy = state.busy,
                    error = state.error,
                    onCreate = { password, confirm ->
                        viewModel.clearError()
                        viewModel.createVault(password, confirm)
                    },
                )

                state.locked -> UnlockScreen(
                    busy = state.busy,
                    error = state.error,
                    onUnlock = {
                        viewModel.clearError()
                        viewModel.unlock(it)
                    },
                )

                else -> VaultRoot(viewModel, state, settings)
            }
        }
    }
}

@Composable
private fun VaultRoot(
    viewModel: MainViewModel,
    state: UiState,
    settings: AppSettings,
) {
    val data = state.data ?: return
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var route by remember { mutableStateOf<Route>(Route.Main) }
    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        val contents = result.contents
        if (!contents.isNullOrBlank()) {
            route = Route.TokenEditor(itemId = null, initialUri = contents)
        }
    }

    BackHandler(enabled = route != Route.Main) {
        route = Route.Main
    }

    val openItem: (VaultItem) -> Unit = { item ->
        route = if (item.kind == ItemKind.TOTP) {
            Route.Detail(item.id)
        } else {
            Route.Detail(item.id)
        }
    }

    when (val current = route) {
        Route.Main -> MainScaffold(
            viewModel = viewModel,
            data = data,
            settings = settings,
            busy = state.busy,
            tab = tab,
            onTab = { tab = it },
            onOpenItem = openItem,
            onAddPassword = { route = Route.PasswordEditor(null) },
            onAddToken = { route = Route.TokenEditor(null) },
            onScanToken = {
                viewModel.prepareExternalActivity()
                scanLauncher.launch(
                    ScanOptions().apply {
                        setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                        setPrompt("扫描 TOTP 二维码")
                        setBeepEnabled(false)
                        setOrientationLocked(false)
                    },
                )
            },
            onLock = viewModel::lock,
            onAccent = viewModel::setAccent,
            onDarkMode = viewModel::setDarkMode,
            onExport = viewModel::exportBackup,
            error = state.error,
            onClearError = viewModel::clearError,
        )

        is Route.Detail -> {
            val item = data.items.firstOrNull { it.id == current.itemId }
            if (item == null) {
                LaunchedEffect(Unit) { route = Route.Main }
            } else {
                ItemDetailScreen(
                    item = item,
                    groups = data.groups,
                    onBack = { route = Route.Main },
                    onEdit = {
                        route = if (item.kind == ItemKind.TOTP) {
                            Route.TokenEditor(item.id)
                        } else {
                            Route.PasswordEditor(item.id)
                        }
                    },
                    onDelete = {
                        viewModel.deleteItem(item.id)
                        route = Route.Main
                    },
                )
            }
        }

        is Route.PasswordEditor -> {
            val item = current.itemId?.let { id -> data.items.firstOrNull { it.id == id } }
            PasswordEditorScreen(
                item = item,
                groups = data.groups,
                onBack = { route = Route.Main },
                onSave = { updated, group ->
                    viewModel.upsertItem(updated, group)
                    route = Route.Main
                },
            )
        }

        is Route.TokenEditor -> {
            val item = current.itemId?.let { id -> data.items.firstOrNull { it.id == id } }
            TokenEditorScreen(
                item = item,
                initialUri = current.initialUri,
                onBack = { route = Route.Main },
                onSave = { updated ->
                    viewModel.upsertItem(updated, "")
                    route = Route.Main
                },
            )
        }
    }
}

@Composable
private fun MainScaffold(
    viewModel: MainViewModel,
    data: top.talyra42.keycase.core.model.VaultData,
    settings: AppSettings,
    busy: Boolean,
    tab: Int,
    onTab: (Int) -> Unit,
    onOpenItem: (VaultItem) -> Unit,
    onAddPassword: () -> Unit,
    onAddToken: () -> Unit,
    onScanToken: () -> Unit,
    onLock: () -> Unit,
    onAccent: (Int) -> Unit,
    onDarkMode: (DarkMode) -> Unit,
    onExport: (android.net.Uri) -> Unit,
    error: String?,
    onClearError: () -> Unit,
) {
    val snackbar = remember { SnackbarHostState() }
    LaunchedEffect(error) {
        if (!error.isNullOrBlank()) {
            snackbar.showSnackbar(error)
            onClearError()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        bottomBar = {
            Column {
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                NavigationBar(
                    containerColor = MaterialTheme.colorScheme.surface,
                    tonalElevation = 0.dp,
                ) {
                    NavigationItem(0, tab, onTab, "首页", Icons.Outlined.Home)
                    NavigationItem(1, tab, onTab, "密码", Icons.Outlined.VpnKey)
                    NavigationItem(2, tab, onTab, "令牌", Icons.Outlined.Schedule)
                    NavigationItem(3, tab, onTab, "设置", Icons.Outlined.Settings)
                }
            }
        },
        floatingActionButton = {
            when (tab) {
                1 -> FloatingActionButton(
                    onClick = onAddPassword,
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                    shape = RoundedCornerShape(16.dp),
                ) {
                    Icon(Icons.Outlined.Add, contentDescription = "新建密码")
                }
                2 -> FloatingActionButton(
                    onClick = onAddToken,
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                    shape = RoundedCornerShape(16.dp),
                ) {
                    Icon(Icons.Outlined.Add, contentDescription = "新建动态令牌")
                }
            }
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            if (busy) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }
            when (tab) {
                0 -> HomeScreen(
                    data = data,
                    onOpenItem = onOpenItem,
                    onOpenAllPasswords = { onTab(1) },
                    onOpenTokens = { onTab(2) },
                    onOpenGroups = { onTab(3) },
                    onOpenSecurity = { onTab(1) },
                )
                1 -> PasswordListScreen(
                    data = data,
                    onOpenItem = onOpenItem,
                )
                2 -> TokenListScreen(
                    data = data,
                    onOpenItem = onOpenItem,
                    onScan = onScanToken,
                )
                else -> SettingsScreen(
                    data = data,
                    settings = settings,
                    onLock = onLock,
                    onAccent = onAccent,
                    onDarkMode = onDarkMode,
                    onExport = onExport,
                    onImport = viewModel::importBackup,
                    onPrepareExternal = viewModel::prepareExternalActivity,
                    onCustomAccent = viewModel::setCustomAccent,
                    onAddGroup = viewModel::addGroup,
                    onRenameGroup = viewModel::renameGroup,
                    onDeleteGroup = viewModel::deleteGroup,
                    onChangePassword = viewModel::changeMasterPassword,
                )
            }
        }
    }
}

@Composable
private fun RowScope.NavigationItem(
    index: Int,
    selected: Int,
    onTab: (Int) -> Unit,
    label: String,
    icon: ImageVector,
) {
    NavigationBarItem(
        selected = selected == index,
        onClick = { onTab(index) },
        icon = { Icon(icon, contentDescription = label) },
        label = { Text(label, style = MaterialTheme.typography.labelSmall) },
        colors = NavigationBarItemDefaults.colors(
            selectedIconColor = MaterialTheme.colorScheme.primary,
            selectedTextColor = MaterialTheme.colorScheme.primary,
            indicatorColor = MaterialTheme.colorScheme.primaryContainer,
            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
        ),
    )
}
