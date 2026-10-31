package top.talyra42.keycase.ui

import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
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
import java.time.Instant
import java.util.UUID

@Composable
fun TokenListScreen(
    data: VaultData,
    onOpenItem: (VaultItem) -> Unit,
    onScan: () -> Unit,
) {
    val items = data.items
        .filter { it.kind == ItemKind.TOTP || it.totp != null }
        .sortedBy { it.title.lowercase() }

    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            now = System.currentTimeMillis()
            delay(500)
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "动态令牌",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = "${items.size} 个验证码 · 每 30 秒更新",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            FilledTonalButton(onClick = onScan) {
                Icon(
                    Icons.Outlined.QrCodeScanner,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(6.dp))
                Text("扫码")
            }
        }

        if (items.isEmpty()) {
            EmptyState(
                icon = Icons.Outlined.Schedule,
                title = "还没有动态令牌",
                subtitle = "扫码或点右下角 + 手动添加。",
            )
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = 20.dp,
                    end = 20.dp,
                    bottom = 96.dp,
                ),
            ) {
                items(items.size, key = { items[it].id }) { index ->
                    val item = items[index]
                    val secret = item.totp
                    val code = secret?.let { runCatching { it.codeAt(now) }.getOrNull() } ?: "—"
                    VaultItemRow(
                        item = item,
                        onClick = { onOpenItem(item) },
                        trailing = {
                            val period = (secret?.period ?: 30).coerceAtLeast(1)
                            val remaining = period - ((now / 1000L) % period)
                            Column(horizontalAlignment = Alignment.End) {
                                Text(
                                    text = code.chunked(3).joinToString(" "),
                                    fontFamily = FontFamily.Monospace,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontSize = 16.sp,
                                )
                                Text(
                                    text = "${remaining}s",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        },
                    )
                }
            }
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
) {
    val existingSecret = item?.totp
    val scanned = remember(initialUri) {
        initialUri?.let { runCatching { OtpauthParser.parse(it) }.getOrNull() }
            ?.takeIf { it.type == OtpType.TOTP }
    }
    var issuer by rememberSaveable(item?.id, initialUri) {
        mutableStateOf(item?.let { it.issuer.ifBlank { it.title } } ?: scanned?.issuer.orEmpty())
    }
    var account by rememberSaveable(item?.id, initialUri) {
        mutableStateOf(item?.username ?: scanned?.account.orEmpty())
    }
    var secret by rememberSaveable(item?.id, initialUri) {
        mutableStateOf(existingSecret?.secret ?: scanned?.secret.orEmpty())
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
    var revealed by remember { mutableStateOf(false) }
    var error by remember {
        mutableStateOf(
            if (initialUri != null && scanned == null) "二维码不是有效的 otpauth 链接" else null,
        )
    }
    var showImport by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (item == null) "添加动态令牌" else "编辑动态令牌") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Outlined.ArrowBack, contentDescription = "取消")
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            val normalized = secret.trim().uppercase().replace(" ", "")
                            if (normalized.isBlank()) {
                                error = "请输入密钥"
                                return@TextButton
                            }
                            val valid = runCatching { Base32.decode(normalized) }.isSuccess
                            if (!valid) {
                                error = "密钥不是有效的 Base32"
                                return@TextButton
                            }
                            val now = Instant.now().toString()
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
                                    type = OtpType.TOTP,
                                    secret = normalized,
                                    algorithm = algorithm,
                                    digits = digits,
                                    period = period,
                                ),
                                updatedAt = now,
                            )
                            onSave(updated)
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
                value = issuer,
                onValueChange = { issuer = it },
                label = { Text("服务名称") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                placeholder = { Text("例如 GitHub") },
            )
            OutlinedTextField(
                value = account,
                onValueChange = { account = it },
                label = { Text("账号") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                placeholder = { Text("例如 lin.dev") },
            )
            OutlinedTextField(
                value = secret,
                onValueChange = { secret = it },
                label = { Text("密钥（Base32）") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
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
                Text(error!!, color = MaterialTheme.colorScheme.error)
            }
            TextButton(onClick = { showImport = true }) {
                Icon(Icons.Outlined.Link, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("从 otpauth 链接导入")
            }
            Text("算法", style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HashAlgorithm.entries.forEach { option ->
                    FilterChip(
                        selected = algorithm == option,
                        onClick = { algorithm = option },
                        label = { Text(option.name) },
                    )
                }
            }
            Text("位数", style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = digits == 6,
                    onClick = { digits = 6 },
                    label = { Text("6 位") },
                )
                FilterChip(
                    selected = digits == 8,
                    onClick = { digits = 8 },
                    label = { Text("8 位") },
                )
            }
            Text("周期", style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = period == 30,
                    onClick = { period = 30 },
                    label = { Text("30 秒") },
                )
                FilterChip(
                    selected = period == 60,
                    onClick = { period = 60 },
                    label = { Text("60 秒") },
                )
            }
            Spacer(Modifier.height(10.dp))
            Text(
                text = "密钥只保存在加密容器里，不联网。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }

    if (showImport) {
        OtpauthImportDialog(
            onDismiss = { showImport = false },
            onImport = { parsed ->
                issuer = parsed.issuer
                account = parsed.account
                secret = parsed.secret
                digits = parsed.digits
                period = parsed.period
                algorithm = parsed.algorithm
                showImport = false
            },
        )
    }
}

@Composable
private fun OtpauthImportDialog(
    onDismiss: () -> Unit,
    onImport: (top.talyra42.keycase.core.otp.ParsedOtp) -> Unit,
) {
    var uri by rememberSaveable { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text("从 otpauth 链接导入") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    "粘贴 otpauth://totp/... 链接；密钥只在本机解析。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = uri,
                    onValueChange = { uri = it },
                    label = { Text("otpauth:// 链接") },
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
                    } else if (parsed.type != OtpType.TOTP) {
                        localError = "目前只支持 TOTP 链接"
                    } else {
                        onImport(parsed)
                    }
                },
            ) { Text("导入") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}
