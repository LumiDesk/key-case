package top.talyra42.keycase.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Restore
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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
                title = { Text("安全中心") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Outlined.ArrowBack, contentDescription = "返回")
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
                EmptyState(
                    icon = Icons.Outlined.Shield,
                    title = "没有发现明显问题",
                    subtitle = "弱密码、重复密码和空密码会显示在这里。",
                )
            } else {
                Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                    Text(
                        text = "${issues.size} 个条目需要处理",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = "列表只做本地检查，不会上传密码。",
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
                                    modifier = Modifier.width(64.dp),
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("回收站") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Outlined.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    TextButton(
                        onClick = { confirmEmpty = true },
                        enabled = deleted.isNotEmpty(),
                    ) { Text("清空") }
                },
            )
        },
    ) { padding ->
        if (deleted.isEmpty()) {
            EmptyState(
                icon = Icons.Outlined.Delete,
                title = "回收站是空的",
                subtitle = "删除的密码和令牌会先放在这里。",
                modifier = Modifier.padding(padding),
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .padding(padding)
                    .fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    bottom = 24.dp,
                ),
            ) {
                items(deleted, key = { it.id }) { item ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Box(modifier = Modifier.weight(1f)) {
                            VaultItemRow(item = item, onClick = {})
                        }
                        IconButton(onClick = { onRestore(item.id) }) {
                            Icon(Icons.Outlined.Restore, contentDescription = "恢复")
                        }
                        IconButton(onClick = { onPurge(item.id) }) {
                            Icon(
                                Icons.Outlined.Delete,
                                contentDescription = "永久删除",
                                tint = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        color = MaterialTheme.colorScheme.outlineVariant,
                    )
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
}
