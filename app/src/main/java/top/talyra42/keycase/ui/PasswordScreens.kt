package top.talyra42.keycase.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.outlined.VpnKey
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
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
import androidx.compose.ui.graphics.Color
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
) {
    var query by rememberSaveable { mutableStateOf("") }
    val items = data.items
        .filter { it.kind == ItemKind.LOGIN }
        .filter {
            query.isBlank() ||
                it.title.contains(query, ignoreCase = true) ||
                it.username.contains(query, ignoreCase = true) ||
                it.urls.any { url -> url.contains(query, ignoreCase = true) }
        }
        .sortedBy { it.title.lowercase() }

    Column(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp)) {
            Text(
                text = "密码",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "${data.items.count { it.kind == ItemKind.LOGIN }} 个条目",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("搜索名称、账号或网址") },
                leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
            )
        }

        if (items.isEmpty()) {
            EmptyState(
                icon = Icons.Outlined.VpnKey,
                title = if (query.isBlank()) "还没有密码" else "没有匹配的条目",
                subtitle = if (query.isBlank()) "点右下角 + 添加第一条。" else "换个关键词试试。",
            )
        } else {
            androidx.compose.foundation.lazy.LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = 20.dp,
                    end = 20.dp,
                    bottom = 96.dp,
                ),
            ) {
                items(items.size, key = { items[it].id }) { index ->
                    VaultItemRow(item = items[index], onClick = { onOpenItem(items[index]) })
                    if (index != items.lastIndex) {
                        HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.18f))
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ItemDetailScreen(
    item: VaultItem,
    groups: List<VaultGroup>,
    onBack: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onIconChange: (IconRef?) -> Unit,
) {
    val context = LocalContext.current
    var revealed by remember(item.id) { mutableStateOf(false) }
    var showDelete by remember { mutableStateOf(false) }
    var showIconPicker by remember { mutableStateOf(false) }
    val groupName = groups.firstOrNull { it.id in item.groupIds }?.name

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (item.kind == ItemKind.TOTP) "动态令牌" else "密码") },
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
            Box {
                BrandAvatar(
                    title = item.title.ifBlank { item.issuer },
                    size = 82.dp,
                    iconRef = item.icon,
                )
                Surface(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .size(48.dp)
                        .clickable { showIconPicker = true },
                    shape = CircleShape,
                    color = Color.Transparent,
                ) {
                    Box(contentAlignment = Alignment.BottomEnd) {
                        Surface(
                            modifier = Modifier.size(28.dp),
                            shape = CircleShape,
                            color = MaterialTheme.colorScheme.surface,
                            border = androidx.compose.foundation.BorderStroke(
                                1.dp,
                                MaterialTheme.colorScheme.outlineVariant,
                            ),
                        ) {
                            Icon(
                                Icons.Outlined.Edit,
                                contentDescription = "更换图标",
                                modifier = Modifier.padding(6.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
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
                        label = "密码",
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
                TotpCard(secret = secret, onCopy = { code -> copyText(context, code) })
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

    if (showIconPicker) {
        IconPickerDialog(
            current = item.icon,
            onDismiss = { showIconPicker = false },
            onPick = { icon ->
                onIconChange(icon)
                showIconPicker = false
            },
        )
    }
}

@Composable
private fun TotpCard(secret: TotpSecret, onCopy: (String) -> Unit) {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(secret.secret) {
        while (true) {
            now = System.currentTimeMillis()
            delay(500)
        }
    }
    val period = secret.period.coerceAtLeast(1)
    val remaining = period - ((now / 1000L) % period)
    val code = runCatching { secret.codeAt(now) }.getOrNull() ?: "—"

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
        ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "动态验证码",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = code.chunked(3).joinToString(" "),
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 2.sp,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
            )
            Text(
                text = "${remaining} 秒后更新",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f),
            )
            Spacer(Modifier.height(10.dp))
            FilledTonalButton(onClick = { onCopy(code) }) {
                Icon(Icons.Outlined.ContentCopy, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text("复制验证码")
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
    val context = LocalContext.current

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (item == null) "新建密码" else "编辑密码") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Outlined.ArrowBack, contentDescription = "取消")
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
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
                                updatedAt = now,
                            )
                            onSave(updated, group.trim())
                        },
                    ) { Text("保存") }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("名称") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
            )
            OutlinedTextField(
                value = username,
                onValueChange = { username = it },
                label = { Text("账号 / 用户名") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
            )
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("密码") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
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
                FilledTonalButton(
                    onClick = { password = generatePassword() },
                ) { Text("生成密码") }
                FilledTonalButton(onClick = { copyText(context, password) }) {
                    Text("复制")
                }
            }
            OutlinedTextField(
                value = url,
                onValueChange = { url = it },
                label = { Text("网址") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
            )
            OutlinedTextField(
                value = group,
                onValueChange = { group = it },
                label = { Text("分组（可选）") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
            )
            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("备注") },
                minLines = 3,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
            )
        }
    }
}

fun copyText(context: Context, value: String) {
    if (value.isBlank()) return
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("KeyCase", value))
    Toast.makeText(context, "已复制", Toast.LENGTH_SHORT).show()
}

private fun generatePassword(): String {
    val chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*"
    val random = SecureRandom()
    return buildString(18) {
        repeat(18) { append(chars[random.nextInt(chars.length)]) }
    }
}
