package top.talyra42.keycase.ui

import androidx.compose.ui.res.stringResource

import top.talyra42.keycase.R
import top.talyra42.keycase.data.AppSettings
import top.talyra42.keycase.data.DarkMode

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import kotlinx.coroutines.launch
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.ui.theme.KeyCaseTheme

sealed interface Route {
    data object Main : Route
    data object Security : Route
    data object Trash : Route
    data object Search : Route
    data class Detail(val itemId: String) : Route
}

private val RouteSaver = Saver<Route, String>(
    save = { route ->
        when (route) {
            Route.Main -> "main"
            Route.Security -> "security"
            Route.Trash -> "trash"
            Route.Search -> "search"
            is Route.Detail -> "detail:${route.itemId}"
        }
    },
    restore = { encoded ->
        when {
            encoded == "main" -> Route.Main
            encoded == "security" -> Route.Security
            encoded == "trash" -> Route.Trash
            encoded == "search" -> Route.Search
            encoded.startsWith("detail:") -> Route.Detail(encoded.removePrefix("detail:"))
            else -> Route.Main
        }
    },
)

@Composable
fun KeyCaseApp(viewModel: MainViewModel) {
    val state by viewModel.state.collectAsState()
    val settings by viewModel.settings.collectAsState()
    val activity = LocalContext.current as? top.talyra42.keycase.MainActivity
    var biometricEnrolled by remember {
        mutableStateOf(activity?.isBiometricEnrolled(state.data?.vaultId) == true)
    }
    val biometricAvailable = activity?.isBiometricAvailable() == true
    val darkTheme = when (settings.darkMode) {
        DarkMode.SYSTEM -> isSystemInDarkTheme()
        DarkMode.LIGHT -> false
        DarkMode.DARK -> true
    }

    SideEffect {
        activity?.let {
            WindowCompat.getInsetsController(it.window, it.window.decorView).apply {
                isAppearanceLightStatusBars = !darkTheme
                isAppearanceLightNavigationBars = !darkTheme
            }
        }
    }

    LaunchedEffect(state.data?.vaultId) {
        // Re-check after unlock/import. A wrapped key from a different vault is
        // cleared by BiometricVault instead of being offered again.
        biometricEnrolled = activity?.isBiometricEnrolled(state.data?.vaultId) == true
    }

    SideEffect {
        if (settings.secureScreen) {
            activity?.window?.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            activity?.window?.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

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
                        val vaultId = state.data?.vaultId
                        if (vaultId.isNullOrBlank()) {
                            biometricEnrolled = false
                        } else {
                            activity?.enableBiometric(vaultId) { ok -> biometricEnrolled = ok }
                        }
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
    var route by rememberSaveable(stateSaver = RouteSaver) { mutableStateOf<Route>(Route.Main) }
    var detailReturn by rememberSaveable(stateSaver = RouteSaver) {
        mutableStateOf<Route>(Route.Main)
    }
    var tab by rememberSaveable { mutableIntStateOf(0) }
    // "" means "new item", null means "editor closed", any other value is an item id.
    var passwordEditorId by rememberSaveable { mutableStateOf<String?>(null) }
    var tokenEditorId by rememberSaveable { mutableStateOf<String?>(null) }
    var tokenInitialUri by remember { mutableStateOf<String?>(null) }
    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        val contents = result.contents
        if (!contents.isNullOrBlank()) {
            if (contents.startsWith("otpauth-migration://")) {
                viewModel.importGoogleMigration(contents)
            } else {
                tokenInitialUri = contents
                tokenEditorId = ""
            }
        }
    }

    BackHandler(enabled = route != Route.Main && passwordEditorId == null && tokenEditorId == null) {
        route = if (route is Route.Detail) detailReturn else Route.Main
    }

    val openItem: (VaultItem) -> Unit = { item ->
        detailReturn = route
        route = Route.Detail(item.id)
    }

    AnimatedContent(
        targetState = route,
        transitionSpec = {
            fun depth(route: Route): Int = when (route) {
                Route.Main -> 0
                is Route.Detail -> 2
                else -> 1
            }
            val forward = depth(targetState) >= depth(initialState)
            if (forward) {
                (slideInHorizontally(tween(200)) { it / 7 } + fadeIn(tween(180))) togetherWith
                    (slideOutHorizontally(tween(160)) { -it / 12 } + fadeOut(tween(120)))
            } else {
                (slideInHorizontally(tween(200)) { -it / 7 } + fadeIn(tween(180))) togetherWith
                    (slideOutHorizontally(tween(160)) { it / 12 } + fadeOut(tween(120)))
            }
        },
        label = "route",
    ) { current ->
    when (current) {
        Route.Main -> MainScaffold(
            viewModel = viewModel,
            data = data,
            settings = settings,
            busy = state.busy,
            initialTab = tab,
            onTabChanged = { tab = it },
            onOpenItem = openItem,
            onAddPassword = {
                tokenInitialUri = null
                passwordEditorId = ""
            },
            onAddToken = {
                tokenInitialUri = null
                tokenEditorId = ""
            },
            onScanToken = {
                viewModel.prepareExternalActivity()
                scanLauncher.launch(
                    ScanOptions().apply {
                        setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                        setPrompt("扫描 TOTP 二维码")
                        setBeepEnabled(false)
                        setOrientationLocked(true)
                    },
                )
            },
            onOpenSecurity = { route = Route.Security },
            onOpenTrash = { route = Route.Trash },
            onOpenSearch = { route = Route.Search },
            onLock = viewModel::lock,
            onAccent = viewModel::setAccent,
            onDarkMode = viewModel::setDarkMode,
            onExport = viewModel::exportBackup,
            error = state.error,
            onClearError = viewModel::clearError,
            message = state.message,
            onClearMessage = viewModel::clearMessage,
            backEnabled = passwordEditorId == null && tokenEditorId == null,
            biometricAvailable = biometricAvailable,
            biometricEnrolled = biometricEnrolled,
            onEnableBiometric = onEnableBiometric,
            onDisableBiometric = onDisableBiometric,
        )

        Route.Security -> SecurityScreen(
            items = data.items,
            onBack = { route = Route.Main },
            onOpenItem = openItem,
        )

        Route.Trash -> TrashScreen(
            items = data.items,
            onBack = { route = Route.Main },
            onRestore = viewModel::restoreItem,
            onPurge = viewModel::purgeItem,
            onEmpty = viewModel::emptyTrash,
        )

        Route.Search -> SearchScreen(
            data = data,
            onBack = { route = Route.Main },
            onOpenItem = openItem,
        )

        is Route.Detail -> {
            val item = data.items.firstOrNull { it.id == current.itemId }
            if (item == null) {
                LaunchedEffect(Unit) { route = detailReturn }
            } else {
                ItemDetailScreen(
                    item = item,
                    showCodes = settings.showTokenCodes,
                    showNext = settings.showNextToken,
                    codeGrouping = settings.codeGrouping,
                    onBack = { route = detailReturn },
                    onEdit = {
                        if (item.kind == ItemKind.TOTP) {
                            tokenInitialUri = null
                            tokenEditorId = item.id
                        } else {
                            passwordEditorId = item.id
                        }
                    },
                    onDelete = {
                        viewModel.deleteItem(item.id)
                        route = detailReturn
                    },
                    onAdvanceHotp = { viewModel.advanceHotp(item.id) },
                    onToggleFavorite = { viewModel.toggleFavorite(item.id) },
                )
            }
        }
    }
    }

    passwordEditorId?.let { editorId ->
        val item = editorId.takeIf { it.isNotBlank() }
            ?.let { id -> data.items.firstOrNull { it.id == id } }
        PasswordEditorScreen(
            item = item,
            onBack = { passwordEditorId = null },
            onSave = { updated ->
                viewModel.upsertItem(updated, "")
                passwordEditorId = null
            },
            onPrepareExternal = viewModel::prepareExternalActivity,
        )
    }

    tokenEditorId?.let { editorId ->
        val item = editorId.takeIf { it.isNotBlank() }
            ?.let { id -> data.items.firstOrNull { it.id == id } }
        TokenEditorScreen(
            item = item,
            initialUri = if (editorId.isBlank()) tokenInitialUri else null,
            onBack = {
                tokenEditorId = null
                tokenInitialUri = null
            },
            onSave = { updated ->
                viewModel.upsertItem(updated, "")
                tokenEditorId = null
                tokenInitialUri = null
            },
            onPrepareExternal = viewModel::prepareExternalActivity,
        )
    }
}

@Composable
private fun MainScaffold(
    viewModel: MainViewModel,
    data: top.talyra42.keycase.core.model.VaultData,
    settings: AppSettings,
    busy: Boolean,
    initialTab: Int,
    onTabChanged: (Int) -> Unit,
    onOpenItem: (VaultItem) -> Unit,
    onAddPassword: () -> Unit,
    onAddToken: () -> Unit,
    onScanToken: () -> Unit,
    onOpenSearch: () -> Unit,
    onOpenSecurity: () -> Unit,
    onOpenTrash: () -> Unit,
    onLock: () -> Unit,
    onAccent: (Int) -> Unit,
    onDarkMode: (DarkMode) -> Unit,
    onExport: (android.net.Uri) -> Unit,
    error: String?,
    onClearError: () -> Unit,
    message: String?,
    onClearMessage: () -> Unit,
    backEnabled: Boolean,
    biometricAvailable: Boolean,
    biometricEnrolled: Boolean,
    onEnableBiometric: () -> Unit,
    onDisableBiometric: () -> Unit,
) {
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val host = LocalContext.current as? Activity
    val exitMessage = localized("再按一次退出")
    val friendlyError = localizedError(error.orEmpty())
    val localizedMessage = localized(message.orEmpty())
    val pagerState = rememberPagerState(initialPage = initialTab, pageCount = { 4 })
    var lastBackAt by remember { mutableLongStateOf(0L) }

    LaunchedEffect(pagerState.currentPage) {
        onTabChanged(pagerState.currentPage)
    }

    fun goToPage(page: Int) {
        scope.launch {
            pagerState.animateScrollToPage(page, animationSpec = tween(220))
        }
    }

    BackHandler(enabled = backEnabled) {
        if (pagerState.currentPage != 0) {
            goToPage(0)
        } else {
            val now = System.currentTimeMillis()
            if (now - lastBackAt <= 2000L) {
                host?.finish()
            } else {
                lastBackAt = now
                scope.launch { snackbar.showSnackbar(exitMessage) }
            }
        }
    }

    LaunchedEffect(error) {
        if (!error.isNullOrBlank()) {
            snackbar.showSnackbar(friendlyError)
            onClearError()
        }
    }
    LaunchedEffect(message) {
        if (!message.isNullOrBlank()) {
            snackbar.showSnackbar(localizedMessage)
            onClearMessage()
        }
    }

    Scaffold(
        snackbarHost = {
            SnackbarHost(snackbar) { data ->
                Snackbar(
                    snackbarData = data,
                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                    contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    actionColor = MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(12.dp),
                )
            }
        },
        bottomBar = {
            Column {
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                NavigationBar(
                    containerColor = MaterialTheme.colorScheme.surface,
                    tonalElevation = 0.dp,
                ) {
                    NavigationItem(0, pagerState.currentPage, { goToPage(it) }, "首页", Icons.Outlined.Home)
                    NavigationItem(1, pagerState.currentPage, { goToPage(it) }, "密码", Icons.Outlined.VpnKey)
                    NavigationItem(2, pagerState.currentPage, { goToPage(it) }, "令牌", Icons.Outlined.Schedule)
                    NavigationItem(3, pagerState.currentPage, { goToPage(it) }, "设置", Icons.Outlined.Settings)
                }
            }
        },
        floatingActionButton = {
            AnimatedVisibility(
                visible = pagerState.targetPage == 1 || pagerState.targetPage == 2,
                enter = fadeIn(tween(220)) + scaleIn(tween(240), initialScale = 0.78f),
                exit = fadeOut(tween(200)) + scaleOut(tween(220), targetScale = 0.78f),
            ) {
                when (pagerState.targetPage) {
                    1 -> FloatingActionButton(
                        onClick = onAddPassword,
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                        shape = RoundedCornerShape(16.dp),
                    ) {
                        Icon(Icons.Outlined.Add, contentDescription = stringResource(R.string.s_d18784c92002))
                    }
                    2 -> ExpandableTokenFab(
                        onManualAdd = onAddToken,
                        onScan = onScanToken,
                    )
                }
            }
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
        ) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize(),
                beyondViewportPageCount = 3,
                key = { it },
            ) { page ->
                when (page) {
                    0 -> HomeScreen(
                        data = data,
                        onOpenItem = onOpenItem,
                        onOpenAllPasswords = { goToPage(1) },
                        onOpenTokens = { goToPage(2) },
                        onOpenSearch = onOpenSearch,
                        onOpenTrash = onOpenTrash,
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
                        active = pagerState.currentPage == 2,
                        showCodes = settings.showTokenCodes,
                        showNext = settings.showNextToken,
                        codeGrouping = settings.codeGrouping,
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
                        onShowTokenCodes = viewModel::setShowTokenCodes,
                        onShowNextToken = viewModel::setShowNextToken,
                        onCodeGrouping = viewModel::setCodeGrouping,
                        onSecureScreen = viewModel::setSecureScreen,
                        onAutoLock = viewModel::setAutoLockSeconds,
                        onAutoBackup = viewModel::setAutoBackup,
                        onBackupFolder = viewModel::setBackupFolder,
                        onBackupNow = viewModel::backupNow,
                        onOpenSecurity = onOpenSecurity,
                        onOpenTrash = onOpenTrash,
                        biometricAvailable = biometricAvailable,
                        biometricEnrolled = biometricEnrolled,
                        onEnableBiometric = onEnableBiometric,
                        onDisableBiometric = onDisableBiometric,
                        onChangePassword = viewModel::changeMasterPassword,
                        onDeleteVault = {
                            onDisableBiometric()
                            viewModel.deleteVault()
                        },
                    )
                }
            }
            if (busy) {
                LinearProgressIndicator(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .fillMaxWidth(),
                )
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
            enter = fadeIn(tween(220)) + expandVertically(tween(220), expandFrom = Alignment.Bottom),
            exit = fadeOut(tween(180)) + shrinkVertically(tween(200), shrinkTowards = Alignment.Bottom),
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
                    text = { Text(stringResource(R.string.s_b8a8fe0d6a8f)) },
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                )
                ExtendedFloatingActionButton(
                    onClick = {
                        expanded = false
                        onManualAdd()
                    },
                    icon = { Icon(Icons.Outlined.Add, contentDescription = null) },
                    text = { Text(stringResource(R.string.s_0307a7752d6c)) },
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
                contentDescription = localized(if (expanded) "收起添加入口" else "添加动态令牌"),
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
