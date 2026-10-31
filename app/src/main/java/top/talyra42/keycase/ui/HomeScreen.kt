package top.talyra42.keycase.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.VpnKey
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
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
    onOpenSearch: () -> Unit,
    onOpenTrash: () -> Unit,
    onOpenSecurity: () -> Unit,
) {
    val activeItems = data.items.filter { it.deletedAt == null }
    val passwords = activeItems.filter { it.kind == ItemKind.LOGIN }
    val tokens = activeItems.filter { it.kind == ItemKind.TOTP }
    val issues = passwordIssueCount(passwords)
    val recent = activeItems.sortedByDescending { it.updatedAt }.take(5)

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
            Text(
                text = "KeyCase",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(12.dp))
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onOpenSearch),
                shape = MaterialTheme.shapes.large,
                color = MaterialTheme.colorScheme.surface,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Outlined.Search,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = "搜索密码、账号、令牌",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
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
                    title = "回收站",
                    count = data.items.count { it.deletedAt != null },
                    icon = Icons.Outlined.Delete,
                    onClick = onOpenTrash,
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
                title = "最近更新",
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
                        VaultItemRow(
                            item = item,
                            onClick = { onOpenItem(item) },
                            trailing = {
                                Icon(
                                    imageVector = if (item.kind == ItemKind.TOTP) {
                                        Icons.Outlined.Schedule
                                    } else {
                                        Icons.Outlined.VpnKey
                                    },
                                    contentDescription = if (item.kind == ItemKind.TOTP) "动态令牌" else "密码",
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.55f),
                                    modifier = Modifier.size(14.dp),
                                )
                            },
                        )
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
