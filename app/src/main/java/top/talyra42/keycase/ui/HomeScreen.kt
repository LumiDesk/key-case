package top.talyra42.keycase.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.VpnKey
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
    onOpenSecurity: () -> Unit,
) {
    val passwords = data.items.filter { it.kind == ItemKind.LOGIN }
    val tokens = data.items.filter { it.kind == ItemKind.TOTP || it.totp != null }
    val issues = passwordIssueCount(passwords)
    val recent = data.items
        .sortedByDescending { it.updatedAt }
        .take(5)

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = 20.dp,
            end = 20.dp,
            top = 18.dp,
            bottom = 96.dp,
        ),
    ) {
        item {
            Text(
                text = "KeyCase",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "密码与动态令牌",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(18.dp))
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatCard(
                    title = "全部密码",
                    count = passwords.size,
                    icon = Icons.Outlined.VpnKey,
                    onClick = onOpenAllPasswords,
                    modifier = Modifier.weight(1f),
                    container = MaterialTheme.colorScheme.primary,
                    content = MaterialTheme.colorScheme.onPrimary,
                )
                StatCard(
                    title = "动态令牌",
                    count = tokens.size,
                    icon = Icons.Outlined.Schedule,
                    onClick = onOpenTokens,
                    modifier = Modifier.weight(1f),
                    container = MaterialTheme.colorScheme.primaryContainer,
                    content = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatCard(
                    title = "待处理",
                    count = issues,
                    icon = Icons.Outlined.Shield,
                    onClick = onOpenSecurity,
                    modifier = Modifier.weight(1f),
                )
                StatCard(
                    title = "回收站",
                    count = 0,
                    icon = Icons.Outlined.Delete,
                    onClick = {},
                    modifier = Modifier.weight(1f),
                )
            }
        }

        item {
            SectionHeader(
                title = "最近使用",
                action = if (data.items.isNotEmpty()) "全部" else null,
                onAction = onOpenAllPasswords,
            )
        }

        if (recent.isEmpty()) {
            item {
                EmptyState(
                    icon = Icons.Outlined.VpnKey,
                    title = "保险库还是空的",
                    subtitle = "去“密码”或“令牌”里添加第一条。",
                )
            }
        } else {
            items(recent, key = { it.id }) { item ->
                VaultItemRow(item = item, onClick = { onOpenItem(item) })
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
