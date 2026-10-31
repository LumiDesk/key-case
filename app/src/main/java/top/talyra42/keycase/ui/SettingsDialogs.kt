package top.talyra42.keycase.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.IntSize
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
fun ImportAegisDialog(
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit,
) {
    var password by rememberSaveable { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text("从 Aegis 导入") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "支持 Aegis 的明文或加密 JSON 导出。加密备份需要输入 Aegis 的主密码；明文备份可留空。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                PasswordInput(password, { password = it }, "Aegis 主密码（可留空）")
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
                    onSubmit(password)
                    onDismiss()
                },
            ) { Text("导入") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

@Composable
fun GoogleMigrationImportDialog(
    onDismiss: () -> Unit,
    onImport: (String) -> Unit,
) {
    var link by rememberSaveable { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text("Google Authenticator 导入") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    "在 Google Authenticator 中选择“转移账号”并复制导出的 otpauth-migration 链接。链接只在本机解析。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = link,
                    onValueChange = { link = it },
                    label = { Text("otpauth-migration:// 链接") },
                    minLines = 3,
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.small,
                )
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
                    val trimmed = link.trim()
                    if (!trimmed.startsWith("otpauth-migration://")) {
                        localError = "请输入 otpauth-migration:// 链接"
                    } else {
                        onImport(trimmed)
                    }
                },
            ) { Text("导入") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
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
    val initialHsv = remember(initial) {
        FloatArray(3).also {
            android.graphics.Color.colorToHSV(
                initial ?: 0xFF2563EB.toInt(),
                it,
            )
        }
    }
    var hue by remember { mutableStateOf(initialHsv[0]) }
    var saturation by remember { mutableStateOf(initialHsv[1]) }
    var value by remember { mutableStateOf(initialHsv[2]) }
    val preview = hsvColor(hue, saturation, value)

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text("自定义强调色") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "在画板上拖动选色；强调色只用于按钮、选中态和小面积图标。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                ColorCanvas(
                    hue = hue,
                    saturation = saturation,
                    value = value,
                    onChange = { s, v ->
                        saturation = s
                        value = v
                    },
                )
                HueSlider(
                    hue = hue,
                    onChange = { hue = it },
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(34.dp)
                            .background(preview, RoundedCornerShape(9.dp))
                            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(9.dp)),
                    )
                    Spacer(Modifier.width(10.dp))
                    Text(
                        text = "#%06X".format(preview.toArgb() and 0xFFFFFF),
                        style = MaterialTheme.typography.bodyMedium,
                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(
                        onClick = {
                            hue = 217f
                            saturation = 0.85f
                            value = 0.93f
                        },
                    ) { Text("恢复默认") }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSubmit(preview.toArgb()) }) { Text("应用") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

@Composable
private fun ColorCanvas(
    hue: Float,
    saturation: Float,
    value: Float,
    onChange: (Float, Float) -> Unit,
) {
    var size by remember { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }
    val update: (androidx.compose.ui.geometry.Offset) -> Unit = { offset ->
        if (size.width > 0 && size.height > 0) {
            onChange(
                (offset.x / size.width).coerceIn(0f, 1f),
                (1f - offset.y / size.height).coerceIn(0f, 1f),
            )
        }
    }
    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(154.dp)
            .clip(RoundedCornerShape(12.dp))
            .onSizeChanged { size = it }
            .pointerInput(hue) {
                detectTapGestures { update(it) }
            }
            .pointerInput(hue) {
                detectDragGestures(
                    onDragStart = { update(it) },
                    onDrag = { change, _ -> update(change.position) },
                )
            },
    ) {
        drawRect(
            brush = androidx.compose.ui.graphics.Brush.horizontalGradient(
                listOf(Color.White, hsvColor(hue, 1f, 1f)),
            ),
        )
        drawRect(
            brush = androidx.compose.ui.graphics.Brush.verticalGradient(
                listOf(Color.Transparent, Color.Black),
            ),
        )
        val marker = androidx.compose.ui.geometry.Offset(
            x = saturation * this.size.width,
            y = (1f - value) * this.size.height,
        )
        drawCircle(Color.White, radius = 7.dp.toPx(), center = marker, style = Stroke(2.dp.toPx()))
        drawCircle(Color.Black.copy(alpha = 0.55f), radius = 7.dp.toPx(), center = marker, style = Stroke(1.dp.toPx()))
    }
}

@Composable
private fun HueSlider(hue: Float, onChange: (Float) -> Unit) {
    var size by remember { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }
    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(22.dp)
            .clip(RoundedCornerShape(11.dp))
            .onSizeChanged { size = it }
            .pointerInput(Unit) {
                detectTapGestures { offset ->
                    if (size.width > 0) onChange((offset.x / size.width).coerceIn(0f, 1f) * 360f)
                }
            }
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = { offset ->
                        if (size.width > 0) onChange((offset.x / size.width).coerceIn(0f, 1f) * 360f)
                    },
                    onDrag = { change, _ ->
                        if (size.width > 0) {
                            onChange((change.position.x / size.width).coerceIn(0f, 1f) * 360f)
                        }
                    },
                )
            },
    ) {
        drawRect(
            brush = androidx.compose.ui.graphics.Brush.horizontalGradient(
                listOf(
                    Color.Red,
                    Color.Yellow,
                    Color.Green,
                    Color.Cyan,
                    Color.Blue,
                    Color.Magenta,
                    Color.Red,
                ),
            ),
        )
        val x = (hue / 360f).coerceIn(0f, 1f) * this.size.width
        drawCircle(Color.White, radius = 8.dp.toPx(), center = Offset(x, this.size.height / 2), style = Stroke(2.dp.toPx()))
        drawCircle(Color.Black.copy(alpha = 0.45f), radius = 8.dp.toPx(), center = Offset(x, this.size.height / 2), style = Stroke(1.dp.toPx()))
    }
}

private fun hsvColor(hue: Float, saturation: Float, value: Float): Color =
    Color(android.graphics.Color.HSVToColor(floatArrayOf(hue, saturation, value)))

