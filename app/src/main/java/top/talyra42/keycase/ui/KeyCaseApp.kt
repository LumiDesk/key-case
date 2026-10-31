package top.talyra42.keycase.ui

import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.VpnKey
import androidx.compose.material3.ExtendedFloatingActionButton
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.ui.theme.KeyCaseTheme

sealed interface Route {
    data object Main : Route
    data object Security : Route
    data object Trash : Route
    data class Detail(val itemId: String) : Route
}

private data class PasswordEditorTarget(val itemId: String?)
private data class TokenEditorTarget(val itemId: String?, val initialUri: String? = null)

@Composable
fun KeyCaseApp(viewModel: MainViewModel) {
    val state by viewModel.state.collectAsState()
    val settings by viewModel.settings.collectAsState()
    val activity = LocalContext.current as? top.talyra42.keycase.MainActivity
    var biometricEnrolled by remember { mutableStateOf(activity?.isBiometricEnrolled() == true) }
    val biometricAvailable = activity?.isBiometricAvailable() == true

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
                    biometricEnabled = biometricEnrolled,
                    onBiometric = { activity?.unlockWithBiometric { } },
                    onUnlock = {
                        viewModel.clearError()
                        viewModel.unlock(it)
                    },
                )

                else -> VaultRoot(
                    viewModel = viewModel,
                    state = state,
                    settings = settings,
                    biometricAvailable = biometricAvailable,
                    biometricEnrolled = biometricEnrolled,
                    onEnableBiometric = {
                        activity?.enableBiometric { ok -> biometricEnrolled = ok }
                    },
                    onDisableBiometric = {
                        activity?.disableBiometric()
                        biometricEnrolled = false
                    },
                )
            }
        }
    }
}

@Composable
private fun VaultRoot(
    viewModel: MainViewModel,
    state: UiState,
    settings: AppSettings,
    biometricAvailable: Boolean,
    biometricEnrolled: Boolean,
    onEnableBiometric: () -> Unit,
    onDisableBiometric: () -> Unit,
) {
    val data = state.data ?: return
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var route by remember { mutableStateOf<Route>(Route.Main) }
    var passwordEditor by remember { mutableStateOf<PasswordEditorTarget?>(null) }
    var tokenEditor by remember { mutableStateOf<TokenEditorTarget?>(null) }
    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        val contents = result.contents
        if (!contents.isNullOrBlank()) {
            if (contents.startsWith("otpauth-migration://")) {
                viewModel.importGoogleMigration(contents)
            } else {
                tokenEditor = TokenEditorTarget(itemId = null, initialUri = contents)
            }
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
            onAddPassword = { passwordEditor = PasswordEditorTarget(null) },
            onAddToken = { tokenEditor = TokenEditorTarget(null) },
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
            onOpenSecurity = { route = Route.Security },
            onOpenTrash = { route = Route.Trash },
            onLock = viewModel::lock,
            onAccent = viewModel::setAccent,
            onDarkMode = viewModel::setDarkMode,
            onExport = viewModel::exportBackup,
            error = state.error,
            onClearError = viewModel::clearError,
            biometricAvailable = biometricAvailable,
            biometricEnrolled = biometricEnrolled,
            onEnableBiometric = onEnableBiometric,
            onDisableBiometric = onDisableBiometric,
        )

        Route.Security -> SecurityScreen(
            items = data.items,
            onBack = { route = Route.Main },
            onOpenItem = { item -> route = Route.Detail(item.id) },
        )

        Route.Trash -> TrashScreen(
            items = data.items,
            onBack = { route = Route.Main },
            onRestore = viewModel::restoreItem,
            onPurge = viewModel::purgeItem,
            onEmpty = viewModel::emptyTrash,
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
                        if (item.kind == ItemKind.TOTP) {
                            tokenEditor = TokenEditorTarget(item.id)
                        } else {
                            passwordEditor = PasswordEditorTarget(item.id)
                        }
                    },
                    onDelete = {
                        viewModel.deleteItem(item.id)
                        route = Route.Main
                    },
                    onIconChange = { icon ->
                        viewModel.upsertItem(item.copy(icon = icon), "")
                    },
                )
            }
        }
    }

    passwordEditor?.let { target ->
        val item = target.itemId?.let { id -> data.items.firstOrNull { it.id == id } }
        PasswordEditorScreen(
            item = item,
            groups = data.groups,
            onBack = { passwordEditor = null },
            onSave = { updated, group ->
                viewModel.upsertItem(updated, group)
                passwordEditor = null
            },
        )
    }

    tokenEditor?.let { target ->
        val item = target.itemId?.let { id -> data.items.firstOrNull { it.id == id } }
        TokenEditorScreen(
            item = item,
            initialUri = target.initialUri,
            onBack = { tokenEditor = null },
            onSave = { updated ->
                viewModel.upsertItem(updated, "")
                tokenEditor = null
            },
        )
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
    onOpenSecurity: () -> Unit,
    onOpenTrash: () -> Unit,
    onLock: () -> Unit,
    onAccent: (Int) -> Unit,
    onDarkMode: (DarkMode) -> Unit,
    onExport: (android.net.Uri) -> Unit,
    error: String?,
    onClearError: () -> Unit,
    biometricAvailable: Boolean,
    biometricEnrolled: Boolean,
    onEnableBiometric: () -> Unit,
    onDisableBiometric: () -> Unit,
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
                2 -> ExpandableTokenFab(
                    onManualAdd = onAddToken,
                    onScan = onScanToken,
                )
            }
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            if (busy) {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }
            AnimatedContent(
                targetState = tab,
                transitionSpec = {
                    val direction = if (targetState > initialState) 1 else -1
                    (slideInHorizontally(tween(220)) { direction * it / 12 } +
                        fadeIn(tween(180))) togetherWith
                        (slideOutHorizontally(tween(160)) { -direction * it / 16 } +
                            fadeOut(tween(120)))
                },
                label = "mainTab",
            ) { currentTab ->
                when (currentTab) {
                    0 -> HomeScreen(
                        data = data,
                        onOpenItem = onOpenItem,
                        onOpenAllPasswords = { onTab(1) },
                        onOpenTokens = { onTab(2) },
                        onOpenGroups = { onTab(3) },
                        onOpenSecurity = onOpenSecurity,
                    )
                    1 -> PasswordListScreen(
                        data = data,
                        onOpenItem = onOpenItem,
                        onAdd = onAddPassword,
                    )
                    2 -> TokenListScreen(
                        data = data,
                        onOpenItem = onOpenItem,
                        onAdd = onAddToken,
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
                        onImportAegis = viewModel::importAegis,
                        onImportGoogle = viewModel::importGoogleMigration,
                        onPrepareExternal = viewModel::prepareExternalActivity,
                        onCustomAccent = viewModel::setCustomAccent,
                        onOpenSecurity = onOpenSecurity,
                        onOpenTrash = onOpenTrash,
                        biometricAvailable = biometricAvailable,
                        biometricEnrolled = biometricEnrolled,
                        onEnableBiometric = onEnableBiometric,
                        onDisableBiometric = onDisableBiometric,
                        onAddGroup = viewModel::addGroup,
                        onRenameGroup = viewModel::renameGroup,
                        onDeleteGroup = viewModel::deleteGroup,
                        onChangePassword = viewModel::changeMasterPassword,
                    )
                }
            }
        }
    }
}

@Composable
private fun ExpandableTokenFab(
    onManualAdd: () -> Unit,
    onScan: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val rotation by animateFloatAsState(
        targetValue = if (expanded) 45f else 0f,
        animationSpec = tween(220),
        label = "tokenFabRotation",
    )
    Column(
        horizontalAlignment = Alignment.End,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        AnimatedVisibility(
            visible = expanded,
            enter = fadeIn(tween(160)) + expandVertically(expandFrom = Alignment.Bottom),
            exit = fadeOut(tween(120)) + shrinkVertically(shrinkTowards = Alignment.Bottom),
        ) {
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ExtendedFloatingActionButton(
                    onClick = {
                        expanded = false
                        onScan()
                    },
                    icon = { Icon(Icons.Outlined.QrCodeScanner, contentDescription = null) },
                    text = { Text("扫码") },
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                )
                ExtendedFloatingActionButton(
                    onClick = {
                        expanded = false
                        onManualAdd()
                    },
                    icon = { Icon(Icons.Outlined.Add, contentDescription = null) },
                    text = { Text("手动添加") },
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                )
            }
        }
        FloatingActionButton(
            onClick = { expanded = !expanded },
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary,
            shape = RoundedCornerShape(16.dp),
        ) {
            Icon(
                Icons.Outlined.Add,
                contentDescription = if (expanded) "收起添加入口" else "添加动态令牌",
                modifier = Modifier.rotate(rotation),
            )
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
