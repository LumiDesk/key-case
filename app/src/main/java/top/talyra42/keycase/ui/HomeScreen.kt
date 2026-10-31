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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.VpnKey
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.model.VaultItem

@Composable
fun HomeScreen(
    data: VaultData,
    onOpenItem: (VaultItem) -> Unit,
    onOpenAllPasswords: () -> Unit,
    onOpenTokens: () -> Unit,
    onOpenGroups: () -> Unit,
    onOpenSecurity: () -> Unit,
) {
    val activeItems = data.items.filter { it.deletedAt == null }
    val passwords = activeItems.filter { it.kind == ItemKind.LOGIN }
    val tokens = activeItems.filter { it.kind == ItemKind.TOTP || it.totp != null }
    val issues = passwordIssueCount(passwords)
    val recent = activeItems.sortedByDescending { it.updatedAt }.take(4)

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = 16.dp,
            end = 16.dp,
            top = 16.dp,
            bottom = 96.dp,
        ),
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "KeyCase",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = "密码与动态令牌 · 仅本机",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Surface(
                    shape = MaterialTheme.shapes.medium,
                    color = MaterialTheme.colorScheme.primaryContainer,
                ) {
                    Icon(
                        Icons.Outlined.Shield,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(8.dp).size(18.dp),
                    )
                }
            }
            Spacer(Modifier.height(14.dp))
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                StatCard(
                    title = "全部密码",
                    count = passwords.size,
                    icon = Icons.Outlined.VpnKey,
                    onClick = onOpenAllPasswords,
                    modifier = Modifier.weight(1f),
                    highlighted = true,
                )
                StatCard(
                    title = "动态令牌",
                    count = tokens.size,
                    icon = Icons.Outlined.Schedule,
                    onClick = onOpenTokens,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                StatCard(
                    title = "分组",
                    count = data.groups.size,
                    icon = Icons.Outlined.Folder,
                    onClick = onOpenGroups,
                    modifier = Modifier.weight(1f),
                )
                StatCard(
                    title = "待处理",
                    count = issues,
                    icon = Icons.Outlined.Shield,
                    onClick = onOpenSecurity,
                    modifier = Modifier.weight(1f),
                )
            }
        }

        item {
            SectionHeader(
                title = "最近使用",
                action = if (activeItems.isNotEmpty()) "全部" else null,
                onAction = onOpenAllPasswords,
            )
        }

        item {
            AppCard {
                if (recent.isEmpty()) {
                    EmptyState(
                        icon = Icons.Outlined.VpnKey,
                        title = "保险库还是空的",
                        subtitle = "在“密码”或“令牌”里添加第一条。",
                        action = {
                            FilledTonalButton(onClick = onOpenAllPasswords) { Text("去添加密码") }
                        },
                    )
                } else {
                    recent.forEachIndexed { index, item ->
                        VaultItemRow(item = item, onClick = { onOpenItem(item) })
                        if (index != recent.lastIndex) {
                            HorizontalDivider(
                                modifier = Modifier.padding(start = 58.dp),
                                color = MaterialTheme.colorScheme.outlineVariant,
                            )
                        }
                    }
                }
            }
        }
    }
}

fun passwordIssueCount(items: List<VaultItem>): Int {
    val common = setOf("123456", "password", "12345678", "qwerty", "111111", "abc123")
    val reused = items.groupBy { it.password }.filterValues { it.size > 1 }.keys
    return items.count { item ->
        val password = item.password
        password.isBlank() ||
            password.length < 8 ||
            password.all(Char::isDigit) ||
            password.lowercase() in common ||
            password in reused
    }
}
