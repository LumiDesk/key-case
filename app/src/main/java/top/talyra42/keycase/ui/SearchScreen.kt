package top.talyra42.keycase.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.model.VaultItem

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
    data: VaultData,
    onBack: () -> Unit,
    onOpenItem: (VaultItem) -> Unit,
) {
    var query by rememberSaveable { mutableStateOf("") }
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    val active = data.items.filter { it.deletedAt == null }
    val normalized = query.trim()
    val results = if (normalized.isEmpty()) {
        emptyList()
    } else {
        active.filter { item ->
            item.title.contains(normalized, ignoreCase = true) ||
                item.issuer.contains(normalized, ignoreCase = true) ||
                item.username.contains(normalized, ignoreCase = true) ||
                item.urls.any { it.contains(normalized, ignoreCase = true) }
        }
    }
    val passwords = results.filter { it.kind == ItemKind.LOGIN }
    val tokens = results.filter { it.kind == ItemKind.TOTP || it.totp != null }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.surface,
        topBar = {
            TopAppBar(
                title = { Text("搜索") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    scrolledContainerColor = Color.Transparent,
                ),
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
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .focusRequester(focusRequester),
                placeholder = { Text("搜索密码、账号、令牌") },
                leadingIcon = {
                    Icon(Icons.Outlined.Search, contentDescription = null, modifier = Modifier.size(18.dp))
                },
                singleLine = true,
                shape = MaterialTheme.shapes.large,
                textStyle = MaterialTheme.typography.bodyMedium,
            )

            when {
            normalized.isEmpty() -> Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                EmptyState(
                    icon = Icons.Outlined.Search,
                    title = "搜索保险库",
                    subtitle = "输入名称、账号、网址或服务名。",
                )
            }

            results.isEmpty() -> Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                EmptyState(
                    icon = Icons.Outlined.Search,
                    title = "没有找到匹配项",
                    subtitle = "换一个关键词试试。",
                )
            }

            else -> LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    top = 6.dp,
                    bottom = 24.dp,
                ),
            ) {
                if (passwords.isNotEmpty()) {
                    item(key = "search-passwords") {
                        SearchSectionHeader("密码", passwords.size)
                    }
                    item(key = "search-passwords-card") {
                        AppCard {
                            passwords.forEachIndexed { index, item ->
                                VaultItemRow(item = item, onClick = { onOpenItem(item) })
                                if (index != passwords.lastIndex) {
                                    HorizontalDivider(
                                        modifier = Modifier.padding(start = 58.dp),
                                        color = MaterialTheme.colorScheme.outlineVariant,
                                    )
                                }
                            }
                        }
                    }
                }
                if (tokens.isNotEmpty()) {
                    item(key = "search-tokens") {
                        SearchSectionHeader("动态令牌", tokens.size)
                    }
                    item(key = "search-tokens-card") {
                        AppCard {
                            tokens.forEachIndexed { index, item ->
                                VaultItemRow(item = item, onClick = { onOpenItem(item) })
                                if (index != tokens.lastIndex) {
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
    }
    }
}

@Composable
private fun SearchSectionHeader(title: String, count: Int) {
    Text(
        text = "$title · $count",
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.Medium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 4.dp, top = 12.dp, bottom = 6.dp),
    )
}
