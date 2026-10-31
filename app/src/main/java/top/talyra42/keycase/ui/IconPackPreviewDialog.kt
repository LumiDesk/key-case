package top.talyra42.keycase.ui

import androidx.compose.ui.res.stringResource

import top.talyra42.keycase.R

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.talyra42.keycase.ui.icons.AegisIconPack
import top.talyra42.keycase.ui.icons.ImportedIconPack

@Composable
fun IconPackPreviewDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    var reload by remember { mutableIntStateOf(0) }
    val builtIn by produceState<List<AegisIconPack.PackIcon>>(emptyList()) {
        value = withContext(Dispatchers.IO) { AegisIconPack.entries(context) }
    }
    val imported by produceState<List<ImportedIconPack.PackIcon>>(
        initialValue = emptyList(),
        reload,
    ) {
        value = withContext(Dispatchers.IO) { ImportedIconPack.list(context) }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text(stringResource(R.string.s_8774aa546e81)) },
        text = {
            if (builtIn.isEmpty() && imported.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 32.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator()
                }
            } else {
                LazyVerticalGrid(
                    columns = GridCells.Fixed(5),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 460.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        Text(
                            "内置图标包 · ${builtIn.size}",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    items(builtIn, key = { "builtin-${it.filename}" }) { icon ->
                        IconPreviewCell(name = icon.name) {
                            PackIconPreview(icon.filename, icon.name, size = 34)
                        }
                    }
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        Text(
                            "已导入图标包 · ${imported.size}",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 8.dp),
                        )
                    }
                    if (imported.isEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }) {
                            Text(
                                stringResource(R.string.s_41f091b4548e),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    } else {
                        imported.groupBy { it.packName }.forEach { (packName, packIcons) ->
                            item(span = { GridItemSpan(maxLineSpan) }, key = "pack-$packName") {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(top = 6.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        "$packName · ${packIcons.size}",
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.weight(1f),
                                    )
                                    IconButton(
                                        onClick = {
                                            ImportedIconPack.delete(context, packName)
                                            reload++
                                        },
                                    ) {
                                        Icon(
                                            Icons.Outlined.Delete,
                                            contentDescription = stringResource(R.string.s_b50cf8aaa30a),
                                            tint = MaterialTheme.colorScheme.error,
                                        )
                                    }
                                }
                            }
                            items(packIcons, key = { "imported-${it.file.absolutePath}" }) { icon ->
                                IconPreviewCell(name = icon.name) {
                                    ImportedIconPreview(icon.file, size = 34)
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.s_33246f6a5e5b)) }
        },
    )
}

@Composable
private fun IconPreviewCell(name: String, icon: @Composable () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        icon()
        Text(
            text = name,
            fontSize = 9.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 2.dp),
        )
    }
}
