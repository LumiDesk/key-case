package top.talyra42.keycase.ui

import androidx.compose.ui.res.stringResource

import top.talyra42.keycase.R
import top.talyra42.keycase.data.CodeGrouping

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.ExpandLess
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.SortByAlpha
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import top.talyra42.keycase.core.model.HashAlgorithm
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.OtpType
import top.talyra42.keycase.core.model.TotpSecret
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.core.otp.Base32
import top.talyra42.keycase.core.otp.OtpauthParser
import top.talyra42.keycase.core.otp.codeAt
import top.talyra42.keycase.core.otp.nextCode
import java.time.Instant
import java.util.UUID

@Composable
fun TokenListScreen(
    data: VaultData,
    onOpenItem: (VaultItem) -> Unit,
    onAdd: () -> Unit,
    onScan: () -> Unit,
    active: Boolean = true,
    showCodes: Boolean = true,
    showNext: Boolean = false,
    codeGrouping: CodeGrouping = CodeGrouping.AUTO,
) {
    var query by rememberSaveable { mutableStateOf("") }
    var searchOpen by rememberSaveable { mutableStateOf(false) }
    var ascending by rememberSaveable { mutableStateOf(true) }
    var revealedId by rememberSaveable { mutableStateOf<String?>(null) }
    val haptic = LocalHapticFeedback.current
    val context = LocalContext.current
    val listState = rememberLazyListState()
    val searchFocus = remember { FocusRequester() }
    val keyboard = LocalSoftwareKeyboardController.current
    LaunchedEffect(searchOpen) {
        if (searchOpen) searchFocus.requestFocus()
    }
    val items = data.items
        .filter { (it.kind == ItemKind.TOTP || it.totp != null) && it.deletedAt == null }
        .filter {
            query.isBlank() ||
                it.title.contains(query, ignoreCase = true) ||
                it.username.contains(query, ignoreCase = true) ||
                it.issuer.contains(query, ignoreCase = true)
        }
    val sections = sectionsOf(items, ascending = ascending)
    val sectionStarts = remember(sections) {
        buildMap {
            var index = 0
            sections.forEach { section ->
                put(section.letter, index)
                index += section.items.size + 1
            }
        }
    }
    val activeLetter = sectionStarts.entries
        .lastOrNull { it.value <= listState.firstVisibleItemIndex }
        ?.key

    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    val blinkTransition = rememberInfiniteTransition(label = "tokenBlink")
    val blinkAlpha by blinkTransition.animateFloat(
        initialValue = 0.35f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(450),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "tokenBlinkAlpha",
    )
    LaunchedEffect(active) {
        if (!active) return@LaunchedEffect
        while (true) {
            val current = System.currentTimeMillis()
            now = current
            // Tick on the next whole second so a 30s boundary is never skipped.
            delay((1000L - current % 1000L).coerceAtLeast(100L))
        }
    }
    LaunchedEffect(revealedId) {
        if (revealedId != null) {
            delay(10_000L)
            revealedId = null
        }
    }

    val backgroundInteraction = remember { MutableInteractionSource() }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .clickable(
                interactionSource = backgroundInteraction,
                indication = null,
            ) { revealedId = null },
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 6.dp, top = 12.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.s_ef773bdc3a26),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.weight(1f))
                IconButton(onClick = {
                    if (searchOpen) {
                        query = ""
                        keyboard?.hide()
                    }
                    searchOpen = !searchOpen
                    revealedId = null
                }) {
                    Icon(
                        if (searchOpen) Icons.Outlined.Close else Icons.Outlined.Search,
                        contentDescription = localized(if (searchOpen) "关闭搜索" else "搜索"),
                        modifier = Modifier.size(20.dp),
                    )
                }
                IconButton(onClick = { ascending = !ascending; revealedId = null }) {
                    Icon(
                        Icons.Outlined.SortByAlpha,
                        contentDescription = localized(if (ascending) "排序 Z-A" else "排序 A-Z"),
                        modifier = Modifier
                            .size(20.dp)
                            .rotate(if (ascending) 0f else 180f),
                    )
                }
            }

            val timedSecrets = items.mapNotNull { it.totp }
                .filter { it.type != OtpType.HOTP }
            if (timedSecrets.isNotEmpty()) {
                val barPeriod = timedSecrets.minOf { it.period }.coerceAtLeast(1)
                val barRemaining = barPeriod - ((now / 1000L) % barPeriod)
                LaunchedEffect(barRemaining, active) {
                    if (active && barRemaining == 5L) {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    }
                }
                val animatedProgress by animateFloatAsState(
                    targetValue = barRemaining / barPeriod.toFloat(),
                    animationSpec = tween(durationMillis = 950, easing = LinearEasing),
                    label = "tokenProgress",
                )
                LinearProgressIndicator(
                    progress = { animatedProgress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .height(2.dp),
                    color = if (barRemaining <= 5) {
                        MaterialTheme.colorScheme.primary.copy(alpha = blinkAlpha)
                    } else {
                        MaterialTheme.colorScheme.primary
                    },
                    trackColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f),
                    gapSize = 0.dp,
                    drawStopIndicator = {},
                )
            }

            AnimatedVisibility(
                visible = searchOpen,
                enter = expandVertically() + fadeIn(),
                exit = shrinkVertically() + fadeOut(),
            ) {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp)
                        .focusRequester(searchFocus),
                    placeholder = { Text(stringResource(R.string.s_3c9585ca7fcd)) },
                    leadingIcon = {
                        Icon(Icons.Outlined.Search, contentDescription = null, modifier = Modifier.size(18.dp))
                    },
                    singleLine = true,
                    shape = MaterialTheme.shapes.small,
                    textStyle = MaterialTheme.typography.bodyMedium,
                )
            }

            if (items.isEmpty()) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    contentAlignment = Alignment.Center,
                ) {
                    EmptyState(
                        icon = Icons.Outlined.Schedule,
                        title = if (query.isBlank()) "还没有动态令牌" else "没有匹配的令牌",
                        subtitle = if (query.isBlank()) "扫码或手动添加第一个令牌。" else "换个关键词试试。",
                        action = if (query.isBlank()) {
                            {
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    FilledTonalButton(onClick = onScan) { Text(stringResource(R.string.s_a129d1844b2e)) }
                                    FilledTonalButton(onClick = onAdd) { Text(stringResource(R.string.s_0307a7752d6c)) }
                                }
                            }
                        } else {
                            null
                        },
                    )
                }
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        start = 16.dp,
                        end = 26.dp,
                        bottom = 96.dp,
                    ),
                ) {
                    sections.forEach { section ->
                        item(key = "header-${section.letter}") {
                            LetterSectionHeader(section.letter)
                        }
                        items(section.items, key = { it.id }) { item ->
                            val secret = item.totp
                            val type = secret?.type ?: OtpType.TOTP
                            val digits = secret?.digits ?: 6
                            val code = secret?.let { runCatching { it.codeAt(now) }.getOrNull() } ?: "—"
                            val nextCode = if (showNext && secret != null && type != OtpType.HOTP) {
                                runCatching { secret.nextCode(now) }.getOrNull()
                            } else {
                                null
                            }
                            val visible = showCodes || revealedId == item.id
                            val codeText = if (visible) {
                                formatTokenCode(code, digits, codeGrouping, type)
                            } else {
                                hiddenTokenCode(digits, codeGrouping, type)
                            }
                            val nextText = if (visible && nextCode != null) {
                                formatTokenCode(nextCode, digits, codeGrouping, type)
                            } else if (nextCode != null) {
                                hiddenTokenCode(digits, codeGrouping, type)
                            } else {
                                null
                            }
                            val codeDescription = if (visible) {
                                localized("验证码") + " " + codeText
                            } else {
                                localized("验证码已隐藏，点击显示并复制")
                            }
                            VaultItemRow(
                                item = item,
                                onClick = {
                                    revealedId = null
                                    onOpenItem(item)
                                },
                                trailing = {
                                    Column(horizontalAlignment = Alignment.End) {
                                        Surface(
                                            shape = RoundedCornerShape(8.dp),
                                            color = MaterialTheme.colorScheme.primaryContainer,
                                            modifier = Modifier
                                                .clip(RoundedCornerShape(8.dp))
                                                .clickable {
                                                    if (!visible) {
                                                        revealedId = item.id
                                                        if (code != "—") copyText(context, code)
                                                    } else if (code != "—") {
                                                        copyText(context, code)
                                                    }
                                                }
                                                .semantics {
                                                    contentDescription = codeDescription
                                                    role = Role.Button
                                                },
                                        ) {
                                            Text(
                                                text = codeText,
                                                fontFamily = FontFamily.Monospace,
                                                fontWeight = FontWeight.SemiBold,
                                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                                                style = MaterialTheme.typography.labelLarge,
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                            )
                                        }
                                        nextText?.let {
                                            Text(
                                                text = it,
                                                fontFamily = FontFamily.Monospace,
                                                fontSize = 10.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                modifier = Modifier.padding(top = 2.dp),
                                            )
                                        }
                                    }
                                },
                            )
                        }
                    }
                }
            }
        }

        if (items.isNotEmpty()) {
            AlphabetIndex(
                letters = AlphabetLetters,
                active = activeLetter,
                listState = listState,
                sectionStarts = sectionStarts,
                availableLetters = sections.map { it.letter }.toSet(),
                modifier = Modifier.align(Alignment.CenterEnd),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TokenEditorScreen(
    item: VaultItem?,
    initialUri: String? = null,
    onBack: () -> Unit,
    onSave: (VaultItem) -> Unit,
    onPrepareExternal: () -> Unit,
) {
    val existingSecret = item?.totp
    val scanned = remember(initialUri) {
        initialUri?.let { runCatching { OtpauthParser.parse(it) }.getOrNull() }
    }
    var issuer by rememberSaveable(item?.id, initialUri) {
        mutableStateOf(item?.let { it.issuer.ifBlank { it.title } } ?: scanned?.issuer.orEmpty())
    }
    var account by rememberSaveable(item?.id, initialUri) {
        mutableStateOf(item?.username ?: scanned?.account.orEmpty())
    }
    // The OTP secret is intentionally memory-only; it must not be written to
    // saved instance state.
    var secret by remember(item?.id, initialUri) {
        mutableStateOf(existingSecret?.secret ?: scanned?.secret.orEmpty())
    }
    var type by rememberSaveable(item?.id, initialUri) {
        mutableStateOf(existingSecret?.type ?: scanned?.type ?: OtpType.TOTP)
    }
    var digits by rememberSaveable(item?.id, initialUri) {
        mutableIntStateOf(existingSecret?.digits ?: scanned?.digits ?: 6)
    }
    var period by rememberSaveable(item?.id, initialUri) {
        mutableIntStateOf(existingSecret?.period ?: scanned?.period ?: 30)
    }
    var algorithm by rememberSaveable(item?.id, initialUri) {
        mutableStateOf(existingSecret?.algorithm ?: scanned?.algorithm ?: HashAlgorithm.SHA1)
    }
    var counter by rememberSaveable(item?.id, initialUri) {
        mutableLongStateOf(existingSecret?.counter ?: scanned?.counter ?: 0L)
    }
    var revealed by remember { mutableStateOf(false) }
    var icon by remember(item?.id) { mutableStateOf(item?.icon) }
    var showIconPicker by remember { mutableStateOf(false) }
    var error by remember {
        mutableStateOf(
            if (initialUri != null && scanned == null) "二维码不是有效的 otpauth 链接" else null,
        )
    }
    var showImport by remember { mutableStateOf(false) }
    var advanced by rememberSaveable(item?.id, initialUri) {
        mutableStateOf(
            (existingSecret?.type ?: scanned?.type)?.let { it != OtpType.TOTP } == true,
        )
    }
    var showDiscard by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val initialTitle = item?.let { it.issuer.ifBlank { it.title } }.orEmpty()
    val dirty = issuer != initialTitle ||
        account != item?.username.orEmpty() ||
        secret != existingSecret?.secret.orEmpty() ||
        type != (existingSecret?.type ?: OtpType.TOTP) ||
        digits != (existingSecret?.digits ?: 6) ||
        period != (existingSecret?.period ?: 30) ||
        algorithm != (existingSecret?.algorithm ?: HashAlgorithm.SHA1) ||
        counter != (existingSecret?.counter ?: 0L) ||
        icon != item?.icon

    fun requestClose() {
        if (dirty) showDiscard = true else onBack()
    }

    fun save() {
        val normalized = secret.trim().uppercase().replace(" ", "")
        if (normalized.isBlank()) {
            error = "请输入密钥"
            return
        }
        if (runCatching { Base32.decode(normalized) }.isFailure) {
            error = "密钥不是有效的 Base32"
            return
        }
        val now = Instant.now().toString()
        val resolvedDigits = if (type == OtpType.STEAM) 5 else digits
        val resolvedPeriod = if (type == OtpType.STEAM) 30 else period
        val resolvedAlgorithm = if (type == OtpType.STEAM) HashAlgorithm.SHA1 else algorithm
        val updated = (item ?: VaultItem(
            id = UUID.randomUUID().toString(),
            kind = ItemKind.TOTP,
            createdAt = now,
        )).copy(
            kind = ItemKind.TOTP,
            title = issuer.trim().ifBlank { account.trim().ifBlank { "动态令牌" } },
            issuer = issuer.trim(),
            username = account.trim(),
            totp = TotpSecret(
                type = type,
                secret = normalized,
                algorithm = resolvedAlgorithm,
                digits = resolvedDigits,
                period = resolvedPeriod,
                counter = if (type == OtpType.HOTP) counter else 0L,
            ),
            icon = icon,
            updatedAt = now,
        )
        onSave(updated)
    }

    ModalBottomSheet(
        onDismissRequest = ::requestClose,
        sheetState = sheetState,
        sheetGesturesEnabled = false,
        containerColor = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        dragHandle = { BottomSheetDefaults.DragHandle() },
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(11.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (item == null) "添加动态令牌" else "编辑动态令牌",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = stringResource(R.string.s_b6d055439fb7),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                IconButton(onClick = ::requestClose) {
                    Icon(Icons.Outlined.Close, contentDescription = stringResource(R.string.s_6c14bd7f6f9e))
                }
            }
            EditorIconRow(
                title = issuer.ifBlank { item?.title.orEmpty() },
                iconRef = icon,
                onClick = { showIconPicker = true },
            )
            OutlinedTextField(
                value = issuer,
                onValueChange = { issuer = it },
                label = { Text(stringResource(R.string.s_d82acb1b50f4)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.small,
                placeholder = { Text(stringResource(R.string.s_67adcaa3dbc0)) },
            )
            OutlinedTextField(
                value = account,
                onValueChange = { account = it },
                label = { Text(stringResource(R.string.s_901384917949)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.small,
                placeholder = { Text(stringResource(R.string.s_9caa9fceede3)) },
            )
            OutlinedTextField(
                value = secret,
                onValueChange = { secret = it },
                label = { Text(stringResource(R.string.s_0bfaa3233e7c)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.small,
                visualTransformation = if (revealed) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done,
                ),
                trailingIcon = {
                    IconButton(onClick = { revealed = !revealed }) {
                        Icon(
                            if (revealed) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility,
                            contentDescription = null,
                        )
                    }
                },
            )
            if (!error.isNullOrBlank()) {
                Text(error!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
            TextButton(onClick = { showImport = true }) {
                Icon(Icons.Outlined.Link, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(stringResource(R.string.s_a32396a99bc5))
            }
            TextButton(
                onClick = { advanced = !advanced },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.s_dd07e641ca66), modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Start)
                Icon(
                    if (advanced) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore,
                    contentDescription = null,
                )
            }
            AnimatedVisibility(
                visible = advanced,
                enter = expandVertically() + fadeIn(),
                exit = shrinkVertically() + fadeOut(),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(stringResource(R.string.s_e4e46c7235d1), style = MaterialTheme.typography.labelLarge)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OtpType.entries.forEach { option ->
                            FilterChip(
                                selected = type == option,
                                onClick = { type = option },
                                label = { Text(option.name) },
                            )
                        }
                    }
                    if (type == OtpType.STEAM) {
                        Text(
                            stringResource(R.string.s_08eafe88e084),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    } else {
                        Text(stringResource(R.string.s_60f424bf4ef4), style = MaterialTheme.typography.labelLarge)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            HashAlgorithm.entries.forEach { option ->
                                FilterChip(
                                    selected = algorithm == option,
                                    onClick = { algorithm = option },
                                    label = { Text(option.name) },
                                )
                            }
                        }
                        Text(stringResource(R.string.s_bded7acbd452), style = MaterialTheme.typography.labelLarge)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilterChip(
                                selected = digits == 6,
                                onClick = { digits = 6 },
                                label = { Text(stringResource(R.string.s_a6263945772c)) },
                            )
                            FilterChip(
                                selected = digits == 8,
                                onClick = { digits = 8 },
                                label = { Text(stringResource(R.string.s_6ae5128722e7)) },
                            )
                        }
                    }
                    if (type == OtpType.TOTP) {
                        Text(stringResource(R.string.s_8a12b12125c2), style = MaterialTheme.typography.labelLarge)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilterChip(
                                selected = period == 30,
                                onClick = { period = 30 },
                                label = { Text(stringResource(R.string.s_262ed709875c)) },
                            )
                            FilterChip(
                                selected = period == 60,
                                onClick = { period = 60 },
                                label = { Text(stringResource(R.string.s_005d45d94f22)) },
                            )
                        }
                    }
                    if (type == OtpType.HOTP) {
                        OutlinedTextField(
                            value = counter.toString(),
                            onValueChange = { value ->
                                counter = value.filter(Char::isDigit).toLongOrNull() ?: 0L
                            },
                            label = { Text(stringResource(R.string.s_ef258428cdc8)) },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                            shape = MaterialTheme.shapes.small,
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Number,
                            ),
                        )
                    }
                }
            }
            Spacer(Modifier.height(2.dp))
            Button(
                onClick = ::save,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 50.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text(stringResource(R.string.s_6484b1da0921), fontWeight = FontWeight.SemiBold)
            }
        }
    }

    if (showImport) {
        OtpauthImportDialog(
            onDismiss = { showImport = false },
            onImport = { parsed ->
                issuer = parsed.issuer
                account = parsed.account
                secret = parsed.secret
                type = parsed.type
                digits = parsed.digits
                period = parsed.period
                algorithm = parsed.algorithm
                counter = parsed.counter
                advanced = true
                showImport = false
            },
        )
    }

    if (showIconPicker) {
        IconPickerDialog(
            current = icon,
            onDismiss = { showIconPicker = false },
            onPick = { picked ->
                icon = picked
                showIconPicker = false
            },
            onPrepareExternal = onPrepareExternal,
        )
    }

    if (showDiscard) {
        ConfirmDialog(
            title = "放弃修改？",
            text = "未保存的修改会丢失。",
            confirmLabel = "放弃",
            onConfirm = {
                showDiscard = false
                onBack()
            },
            onDismiss = { showDiscard = false },
        )
    }
}

@Composable
private fun OtpauthImportDialog(
    onDismiss: () -> Unit,
    onImport: (top.talyra42.keycase.core.otp.ParsedOtp) -> Unit,
) {
    var uri by remember { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text(stringResource(R.string.s_a32396a99bc5)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    stringResource(R.string.s_89ad265a8a8f),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = uri,
                    onValueChange = { uri = it },
                    label = { Text(stringResource(R.string.s_da31debfb073)) },
                    minLines = 3,
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.small,
                )
                localError?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val parsed = runCatching { OtpauthParser.parse(uri.trim()) }.getOrNull()
                    if (parsed == null) {
                        localError = "链接格式无效"
                    } else {
                        onImport(parsed)
                    }
                },
            ) { Text(stringResource(R.string.s_60e2bcad85ac)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.s_4d0b4688c787)) }
        },
    )
}
