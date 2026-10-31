package top.talyra42.keycase.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
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
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.SortByAlpha
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.outlined.VpnKey
import androidx.compose.material3.Button
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.IconRef
import top.talyra42.keycase.core.model.TotpSecret
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.model.VaultGroup
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.core.otp.Base32
import top.talyra42.keycase.core.otp.codeAt
import top.talyra42.keycase.ui.icons.BrandAvatar
import java.security.SecureRandom
import java.time.Instant
import java.util.UUID

@Composable
fun PasswordListScreen(
    data: VaultData,
    onOpenItem: (VaultItem) -> Unit,
    onAdd: () -> Unit,
) {
    var query by rememberSaveable { mutableStateOf("") }
    var searchOpen by rememberSaveable { mutableStateOf(false) }
    var ascending by rememberSaveable { mutableStateOf(true) }
    val listState = rememberLazyListState()
    val items = data.items
        .filter { it.kind == ItemKind.LOGIN && it.deletedAt == null }
        .filter {
            query.isBlank() ||
                it.title.contains(query, ignoreCase = true) ||
                it.username.contains(query, ignoreCase = true) ||
                it.urls.any { url -> url.contains(query, ignoreCase = true) }
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

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 6.dp, top = 12.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "密码",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.weight(1f))
                IconButton(onClick = { searchOpen = !searchOpen }) {
                    Icon(
                        if (searchOpen) Icons.Outlined.Close else Icons.Outlined.Search,
                        contentDescription = if (searchOpen) "关闭搜索" else "搜索",
                        modifier = Modifier.size(20.dp),
                    )
                }
                IconButton(onClick = { ascending = !ascending }) {
                    Icon(
                        Icons.Outlined.SortByAlpha,
                        contentDescription = if (ascending) "排序 Z-A" else "排序 A-Z",
                        modifier = Modifier
                            .size(20.dp)
                            .rotate(if (ascending) 0f else 180f),
                    )
                }
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
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    placeholder = { Text("搜索名称、账号或网址") },
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
                        icon = Icons.Outlined.VpnKey,
                        title = if (query.isBlank()) "还没有密码" else "没有匹配的条目",
                        subtitle = if (query.isBlank()) "点右下角 + 添加第一条。" else "换个关键词试试。",
                        action = if (query.isBlank()) {
                            { FilledTonalButton(onClick = onAdd) { Text("添加密码") } }
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
                            VaultItemRow(
                                item = item,
                                onClick = { onOpenItem(item) },
                                trailing = if (item.favorite) {
                                    {
                                        Icon(
                                            Icons.Outlined.Star,
                                            contentDescription = "收藏",
                                            tint = MaterialTheme.colorScheme.primary,
                                            modifier = Modifier.size(15.dp),
                                        )
                                    }
                                } else {
                                    null
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
fun ItemDetailScreen(
    item: VaultItem,
    groups: List<VaultGroup>,
    showCodes: Boolean = true,
    showNext: Boolean = false,
    onBack: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val context = LocalContext.current
    var revealed by remember(item.id) { mutableStateOf(false) }
    var showDelete by remember { mutableStateOf(false) }
    val groupName = groups.firstOrNull { it.id in item.groupIds }?.name

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (item.kind == ItemKind.TOTP) "令牌详情" else "登录密码") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Outlined.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    IconButton(onClick = onEdit) {
                        Icon(Icons.Outlined.Edit, contentDescription = "编辑")
                    }
                    IconButton(onClick = { showDelete = true }) {
                        Icon(Icons.Outlined.Delete, contentDescription = "删除")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            BrandAvatar(
                title = item.title.ifBlank { item.issuer },
                size = 82.dp,
                iconRef = item.icon,
            )
            Spacer(Modifier.height(14.dp))
            Text(
                text = item.title.ifBlank { "未命名" },
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            if (item.username.isNotBlank()) {
                Text(
                    text = item.username,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (!groupName.isNullOrBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(
                    text = groupName,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                )
            }
            Spacer(Modifier.height(18.dp))

            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            ) {
                InfoRow(label = "账号", value = item.username.ifBlank { "—" }) {
                    CopyButton { copyText(context, item.username) }
                }
                if (item.password.isNotBlank()) {
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.18f))
                    InfoRow(
                        label = "登录密码",
                        value = if (revealed) item.password else "••••••••",
                    ) {
                        IconButton(onClick = { revealed = !revealed }) {
                            Icon(
                                imageVector = if (revealed) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility,
                                contentDescription = if (revealed) "隐藏密码" else "显示密码",
                            )
                        }
                        CopyButton { copyText(context, item.password) }
                    }
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.18f))
                }
                if (item.urls.isNotEmpty()) {
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.18f))
                    InfoRow(label = "网址", value = item.urls.first()) {
                        CopyButton { copyText(context, item.urls.first()) }
                    }
                }
                if (item.notes.isNotBlank()) {
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.18f))
                    InfoRow(label = "备注", value = item.notes, muted = true)
                }
                HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.18f))
                InfoRow(label = "更新", value = item.updatedAt.take(16).replace('T', ' '), muted = true)
            }

            item.totp?.let { secret ->
                Spacer(Modifier.height(14.dp))
                TotpCard(
                    secret = secret,
                    showCodes = showCodes,
                    showNext = showNext,
                    onCopy = { code -> copyText(context, code) },
                )
            }

            Spacer(Modifier.height(24.dp))
        }
    }

    if (showDelete) {
        ConfirmDialog(
            title = "删除这个条目？",
            text = "删除后无法恢复。",
            onConfirm = {
                showDelete = false
                onDelete()
            },
            onDismiss = { showDelete = false },
        )
    }
}

@Composable
private fun TotpCard(
    secret: TotpSecret,
    showCodes: Boolean,
    showNext: Boolean,
    onCopy: (String) -> Unit,
) {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var revealed by remember(secret.secret) { mutableStateOf(false) }
    LaunchedEffect(secret.secret) {
        while (true) {
            now = System.currentTimeMillis()
            delay(1000)
        }
    }
    val period = secret.period.coerceAtLeast(1)
    val remaining = period - ((now / 1000L) % period)
    val code = runCatching { secret.codeAt(now) }.getOrNull() ?: "—"
    val visible = showCodes || revealed
    val nextCode = if (showNext) {
        runCatching { secret.codeAt(now + period * 1000L) }.getOrNull()
    } else {
        null
    }
    val progress by animateFloatAsState(
        targetValue = remaining / period.toFloat(),
        animationSpec = tween(durationMillis = 950, easing = LinearEasing),
        label = "detailTokenProgress",
    )
    val blinkTransition = rememberInfiniteTransition(label = "detailTokenBlink")
    val blinkAlpha by blinkTransition.animateFloat(
        initialValue = 0.35f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(450),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "detailTokenBlinkAlpha",
    )

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable {
                if (!visible) {
                    revealed = true
                    if (code != "—") onCopy(code)
                } else if (code != "—") {
                    onCopy(code)
                }
            },
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
        ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 18.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (visible) code.chunked(3).joinToString(" ") else "••• •••",
                    fontSize = 30.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    letterSpacing = 2.sp,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
                if (nextCode != null) {
                    Text(
                        text = if (visible) {
                            nextCode.chunked(3).joinToString(" ")
                        } else {
                            "••• •••"
                        },
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.6f),
                    )
                }
            }
            Box(modifier = Modifier.size(42.dp), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(
                    progress = { progress },
                    modifier = Modifier.fillMaxSize(),
                    strokeWidth = 3.dp,
                    color = if (remaining <= 5) {
                        MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = blinkAlpha)
                    } else {
                        MaterialTheme.colorScheme.onPrimaryContainer
                    },
                    trackColor = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.16f),
                )
            }
        }
    }
}

@Composable
private fun CopyButton(onClick: () -> Unit) {
    IconButton(onClick = onClick) {
        Icon(
            Icons.Outlined.ContentCopy,
            contentDescription = "复制",
            modifier = Modifier.size(18.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PasswordEditorScreen(
    item: VaultItem?,
    groups: List<VaultGroup>,
    onBack: () -> Unit,
    onSave: (VaultItem, String) -> Unit,
) {
    var title by rememberSaveable(item?.id) { mutableStateOf(item?.title.orEmpty()) }
    var username by rememberSaveable(item?.id) { mutableStateOf(item?.username.orEmpty()) }
    var password by rememberSaveable(item?.id) { mutableStateOf(item?.password.orEmpty()) }
    var url by rememberSaveable(item?.id) { mutableStateOf(item?.urls?.firstOrNull().orEmpty()) }
    var notes by rememberSaveable(item?.id) { mutableStateOf(item?.notes.orEmpty()) }
    var group by rememberSaveable(item?.id) {
        mutableStateOf(
            groups.firstOrNull { it.id in (item?.groupIds ?: emptyList()) }?.name.orEmpty(),
        )
    }
    var revealed by remember { mutableStateOf(false) }
    var icon by remember(item?.id) { mutableStateOf(item?.icon) }
    var showIconPicker by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    fun save() {
        val now = Instant.now().toString()
        val updated = (item ?: VaultItem(
            id = UUID.randomUUID().toString(),
            kind = ItemKind.LOGIN,
            createdAt = now,
        )).copy(
            kind = ItemKind.LOGIN,
            title = title.trim().ifBlank { "未命名" },
            username = username.trim(),
            password = password,
            urls = if (url.isBlank()) emptyList() else listOf(url.trim()),
            notes = notes.trim(),
            icon = icon,
            updatedAt = now,
        )
        onSave(updated, group.trim())
    }

    ModalBottomSheet(
        onDismissRequest = onBack,
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
                        text = if (item == null) "新建密码" else "编辑密码",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = "保存到本地加密保险库",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                IconButton(onClick = onBack) {
                    Icon(Icons.Outlined.Close, contentDescription = "关闭")
                }
            }
            Spacer(Modifier.height(2.dp))
            EditorIconRow(
                title = title.ifBlank { item?.title.orEmpty() },
                iconRef = icon,
                onClick = { showIconPicker = true },
            )
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("名称") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.small,
            )
            OutlinedTextField(
                value = username,
                onValueChange = { username = it },
                label = { Text("账号 / 用户名") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.small,
            )
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("登录密码") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.small,
                visualTransformation = if (revealed) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Next,
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
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilledTonalButton(onClick = { password = generatePassword() }) {
                    Text("生成密码")
                }
                FilledTonalButton(onClick = { copyText(context, password) }) {
                    Text("复制")
                }
            }
            OutlinedTextField(
                value = url,
                onValueChange = { url = it },
                label = { Text("网址（可选）") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.small,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
            )
            OutlinedTextField(
                value = group,
                onValueChange = { group = it },
                label = { Text("分组（可选）") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.small,
            )
            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("备注（可选）") },
                minLines = 2,
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.small,
            )
            Spacer(Modifier.height(4.dp))
            Button(
                onClick = ::save,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text("保存密码", fontWeight = FontWeight.SemiBold)
            }
        }
    }

    if (showIconPicker) {
        IconPickerDialog(
            current = icon,
            onDismiss = { showIconPicker = false },
            onPick = { picked ->
                icon = picked
                showIconPicker = false
            },
        )
    }
}

fun copyText(context: Context, value: String) {
    if (value.isBlank()) return
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("KeyCase", value))
    Toast.makeText(
        context,
        if (java.util.Locale.getDefault().language.startsWith("zh")) "已复制" else "Copied",
        Toast.LENGTH_SHORT,
    ).show()
}

private fun generatePassword(): String {
    val chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*"
    val random = SecureRandom()
    return buildString(18) {
        repeat(18) { append(chars[random.nextInt(chars.length)]) }
    }
}
