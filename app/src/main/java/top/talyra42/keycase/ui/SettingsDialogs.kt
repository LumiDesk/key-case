package top.talyra42.keycase.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import top.talyra42.keycase.core.model.VaultGroup

@Composable
fun ChangeMasterPasswordDialog(
    onDismiss: () -> Unit,
    onSubmit: (current: String, newPassword: String, confirm: String) -> Unit,
) {
    var current by rememberSaveable { mutableStateOf("") }
    var newPassword by rememberSaveable { mutableStateOf("") }
    var confirm by rememberSaveable { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text("修改主密码") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "修改后旧主密码立即失效；请牢记新密码。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                PasswordInput(current, { current = it }, "当前主密码")
                PasswordInput(newPassword, { newPassword = it }, "新主密码（至少 8 位）")
                PasswordInput(confirm, { confirm = it }, "再次输入新主密码")
                localError?.let {
                    Text(
                        it,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (newPassword.length < 8) {
                        localError = "新主密码至少 8 位"
                    } else if (newPassword != confirm) {
                        localError = "两次输入的新主密码不一致"
                    } else {
                        onSubmit(current, newPassword, confirm)
                        onDismiss()
                    }
                },
            ) { Text("更新") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

@Composable
private fun PasswordInput(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.small,
        visualTransformation = PasswordVisualTransformation(),
    )
}

@Composable
fun ImportBackupDialog(
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit,
) {
    var password by rememberSaveable { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text("导入加密备份") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "导入会替换当前保险库；当前数据不会自动合并。请输入备份文件的主密码。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                PasswordInput(password, { password = it }, "备份的主密码")
                localError?.let {
                    Text(
                        it,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (password.isBlank()) {
                        localError = "请输入主密码"
                    } else {
                        onSubmit(password)
                        onDismiss()
                    }
                },
            ) { Text("导入并替换") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

fun parseAccentHex(input: String): Int? {
    val raw = input.trim().removePrefix("#")
    return when (raw.length) {
        6 -> runCatching { (0xFF000000L or raw.toLong(16)).toInt() }.getOrNull()
        8 -> runCatching { raw.toLong(16).toInt() }.getOrNull()
        else -> null
    }
}

@Composable
fun CustomAccentDialog(
    initial: Int?,
    onDismiss: () -> Unit,
    onSubmit: (Int) -> Unit,
) {
    var value by rememberSaveable {
        mutableStateOf(initial?.let { "#%06X".format(it and 0xFFFFFF) } ?: "#2563EB")
    }
    var localError by remember { mutableStateOf<String?>(null) }
    val preview = parseAccentHex(value)

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text("自定义强调色") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "输入 #RRGGBB 或 #AARRGGBB。强调色只用于按钮、选中态和小面积图标。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .background(
                                preview?.let { androidx.compose.ui.graphics.Color(it) }
                                    ?: MaterialTheme.colorScheme.surfaceVariant,
                                RoundedCornerShape(10.dp),
                            ),
                    )
                    Spacer(Modifier.width(10.dp))
                    OutlinedTextField(
                        value = value,
                        onValueChange = { value = it },
                        label = { Text("颜色值") },
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                        shape = MaterialTheme.shapes.small,
                        isError = preview == null,
                    )
                }
                localError?.let {
                    Text(
                        it,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val parsed = parseAccentHex(value)
                    if (parsed == null) {
                        localError = "颜色格式无效"
                    } else {
                        onSubmit(parsed)
                    }
                },
            ) { Text("应用") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

@Composable
fun GroupManagerDialog(
    groups: List<VaultGroup>,
    itemCounts: Map<String, Int>,
    onAdd: (String) -> Unit,
    onRename: (String, String) -> Unit,
    onDelete: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var newName by rememberSaveable { mutableStateOf("") }
    var renaming by remember { mutableStateOf<VaultGroup?>(null) }
    var deleting by remember { mutableStateOf<VaultGroup?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text("分组") },
        text = {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value = newName,
                        onValueChange = { newName = it },
                        placeholder = { Text("新分组名称") },
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                        shape = MaterialTheme.shapes.small,
                    )
                    Spacer(Modifier.width(6.dp))
                    IconButton(
                        onClick = {
                            if (newName.isNotBlank()) {
                                onAdd(newName)
                                newName = ""
                            }
                        },
                    ) {
                        Icon(Icons.Outlined.Add, contentDescription = "添加分组")
                    }
                }
                Spacer(Modifier.height(8.dp))
                if (groups.isEmpty()) {
                    Text(
                        "还没有分组。分组只是整理标签，不会移动或加密条目。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 12.dp),
                    )
                } else {
                    LazyColumn(modifier = Modifier.heightIn(max = 320.dp)) {
                        items(groups.size, key = { groups[it].id }) { index ->
                            val group = groups[index]
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(group.name, style = MaterialTheme.typography.bodyLarge)
                                    Text(
                                        "${itemCounts[group.id] ?: 0} 个条目",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                IconButton(onClick = { renaming = group }) {
                                    Icon(Icons.Outlined.Edit, contentDescription = "重命名")
                                }
                                IconButton(onClick = { deleting = group }) {
                                    Icon(
                                        Icons.Outlined.Delete,
                                        contentDescription = "删除",
                                        tint = MaterialTheme.colorScheme.error,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("完成") }
        },
    )

    renaming?.let { group ->
        var value by remember(group.id) { mutableStateOf(group.name) }
        AlertDialog(
            onDismissRequest = { renaming = null },
            title = { Text("重命名分组") },
            text = {
                OutlinedTextField(
                    value = value,
                    onValueChange = { value = it },
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        onRename(group.id, value)
                        renaming = null
                    },
                ) { Text("保存") }
            },
            dismissButton = {
                TextButton(onClick = { renaming = null }) { Text("取消") }
            },
        )
    }

    deleting?.let { group ->
        ConfirmDialog(
            title = "删除分组“${group.name}”？",
            text = "条目本身不会被删除，只会从该分组的标签中移除。",
            confirmLabel = "删除分组",
            onConfirm = {
                onDelete(group.id)
                deleting = null
            },
            onDismiss = { deleting = null },
        )
    }
}
