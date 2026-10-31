package top.talyra42.keycase.ui

import androidx.compose.ui.res.stringResource

import top.talyra42.keycase.R

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Restore
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.ui.icons.BrandAvatar

data class SecurityIssue(
    val item: VaultItem,
    val reason: String,
)

fun securityIssues(items: List<VaultItem>): List<SecurityIssue> {
    val common = setOf("123456", "password", "12345678", "qwerty", "111111", "abc123")
    val reused = items.groupBy { it.password }.filterValues { it.size > 1 }.keys
    return items.mapNotNull { item ->
        val password = item.password
        val reason = when {
            password.isBlank() -> "没有密码"
            password.length < 8 -> "密码太短"
            password.all(Char::isDigit) -> "只有数字"
            password.lowercase() in common -> "常见弱密码"
            password in reused -> "密码重复"
            else -> null
        }
        reason?.let { SecurityIssue(item, it) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SecurityScreen(
    items: List<VaultItem>,
    onBack: () -> Unit,
    onOpenItem: (VaultItem) -> Unit,
) {
    val active = items.filter { it.kind == ItemKind.LOGIN && it.deletedAt == null }
    val issues = securityIssues(active)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.s_9e5447826cdd)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.s_11d024154013))
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
        ) {
            if (issues.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    EmptyState(
                        icon = Icons.Outlined.Shield,
                        title = "没有发现明显问题",
                        subtitle = "弱密码、重复密码和空密码会显示在这里。",
                    )
                }
            } else {
                Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                    Text(
                        text = "${issues.size} 个条目需要处理",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = stringResource(R.string.s_511bf881372a),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        start = 16.dp,
                        end = 16.dp,
                        bottom = 24.dp,
                    ),
                ) {
                    items(issues, key = { it.item.id }) { issue ->
                        VaultItemRow(
                            item = issue.item,
                            onClick = { onOpenItem(issue.item) },
                            trailing = {
                                Text(
                                    text = issue.reason,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.error,
                                    modifier = Modifier.widthIn(min = 64.dp),
                                )
                            },
                        )
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 52.dp),
                            color = MaterialTheme.colorScheme.outlineVariant,
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TrashScreen(
    items: List<VaultItem>,
    onBack: () -> Unit,
    onRestore: (String) -> Unit,
    onPurge: (String) -> Unit,
    onEmpty: () -> Unit,
) {
    val deleted = items.filter { it.deletedAt != null }
    var confirmEmpty by remember { mutableStateOf(false) }
    var pendingPurge by remember { mutableStateOf<VaultItem?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.s_64ea8751fba9)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.s_11d024154013))
                    }
                },
                actions = {
                    TextButton(
                        onClick = { confirmEmpty = true },
                        enabled = deleted.isNotEmpty(),
                    ) { Text(stringResource(R.string.s_84fcd70d4280)) }
                },
            )
        },
    ) { padding ->
        if (deleted.isEmpty()) {
            Box(
                modifier = Modifier
                    .padding(padding)
                    .fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                EmptyState(
                    icon = Icons.Outlined.Delete,
                    title = "回收站是空的",
                    subtitle = "删除的密码和令牌会先放在这里。",
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .padding(padding)
                    .fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = 12.dp,
                    end = 12.dp,
                    top = 8.dp,
                    bottom = 24.dp,
                ),
            ) {
                item {
                    Text(
                        text = "${deleted.size} 个已删除条目",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 8.dp),
                    )
                }
                items(deleted, key = { it.id }) { item ->
                    AppCard(modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp)) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 10.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            BrandAvatar(
                                title = item.title.ifBlank { item.issuer },
                                size = 38.dp,
                                iconRef = item.icon,
                            )
                            Spacer(Modifier.width(10.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = item.title.ifBlank { "未命名" },
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    maxLines = 1,
                                )
                                Text(
                                    text = item.username.ifBlank {
                                        if (item.kind == ItemKind.TOTP) "动态令牌" else "登录密码"
                                    },
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                )
                                Text(
                                    text = "删除于 " + formatDeletedAt(item.deletedAt.orEmpty()),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.outline,
                                )
                            }
                            IconButton(onClick = { onRestore(item.id) }) {
                                Icon(
                                    Icons.Outlined.Restore,
                                    contentDescription = stringResource(R.string.s_79748ca1c6e5),
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                            }
                            IconButton(onClick = { pendingPurge = item }) {
                                Icon(
                                    Icons.Outlined.Delete,
                                    contentDescription = stringResource(R.string.s_a7fadbe126d2),
                                    tint = MaterialTheme.colorScheme.error,
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (confirmEmpty) {
        ConfirmDialog(
            title = "清空回收站？",
            text = "所有已删除条目会被永久删除，无法恢复。",
            confirmLabel = "清空",
            onConfirm = {
                confirmEmpty = false
                onEmpty()
            },
            onDismiss = { confirmEmpty = false },
        )
    }

    pendingPurge?.let { item ->
        ConfirmDialog(
            title = "永久删除这个条目？",
            text = "此操作无法撤销。",
            confirmLabel = "永久删除",
            onConfirm = {
                pendingPurge = null
                onPurge(item.id)
            },
            onDismiss = { pendingPurge = null },
        )
    }
}
