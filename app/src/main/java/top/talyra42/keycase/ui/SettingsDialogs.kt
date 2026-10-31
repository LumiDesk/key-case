package top.talyra42.keycase.ui

import androidx.compose.ui.res.stringResource

import top.talyra42.keycase.R

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
    // All credentials and secret-bearing links below are memory-only. Saving
    // them in instance state would outlive the dialog and defeat the vault's
    // threat model.
    var current by remember { mutableStateOf("") }
    var newPassword by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text(stringResource(R.string.s_eedebcf226bb)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    stringResource(R.string.s_6f8a44914e4e),
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
            ) { Text(stringResource(R.string.s_d9db02d07adb)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.s_4d0b4688c787)) }
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
    var password by remember { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text(stringResource(R.string.s_12e25858d323)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    stringResource(R.string.s_9233d04f12a4),
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
            ) { Text(stringResource(R.string.s_60e2bcad85ac)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.s_4d0b4688c787)) }
        },
    )
}

@Composable
fun GoogleMigrationImportDialog(
    onDismiss: () -> Unit,
    onImport: (String) -> Unit,
) {
    var link by remember { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text(stringResource(R.string.s_5937a1f6388d)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    stringResource(R.string.s_58fdb0fae9d3),
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
            ) { Text(stringResource(R.string.s_60e2bcad85ac)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.s_4d0b4688c787)) }
        },
    )
}

@Composable
fun ImportBackupDialog(
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit,
) {
    var password by remember { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text(stringResource(R.string.s_887228e85437)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    stringResource(R.string.s_716805cb7f94),
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
            ) { Text(stringResource(R.string.s_fe6c375858c1)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.s_4d0b4688c787)) }
        },
    )
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
        title = { Text(stringResource(R.string.s_a3415054030e)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    stringResource(R.string.s_2323942d0605),
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
                    ) { Text(stringResource(R.string.s_a191935bc678)) }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSubmit(preview.toArgb()) }) { Text(stringResource(R.string.s_4562024ddec7)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.s_4d0b4688c787)) }
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

