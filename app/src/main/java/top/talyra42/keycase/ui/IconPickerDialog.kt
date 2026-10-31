package top.talyra42.keycase.ui

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.talyra42.keycase.core.model.IconRef
import top.talyra42.keycase.ui.icons.AegisIconPack
import java.io.ByteArrayOutputStream
import androidx.compose.runtime.rememberCoroutineScope

@Composable
fun IconPickerDialog(
    current: IconRef?,
    onDismiss: () -> Unit,
    onPick: (IconRef?) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val icons by produceState<List<AegisIconPack.PackIcon>>(emptyList()) {
        value = withContext(Dispatchers.IO) { AegisIconPack.entries(context) }
    }
    var query by rememberSaveable { mutableStateOf("") }
    var imageError by remember { mutableStateOf<String?>(null) }
    val imagePicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            scope.launch {
                val encoded = withContext(Dispatchers.IO) { loadScaledIcon(context, uri) }
                if (encoded == null) {
                    imageError = "无法读取这张图片"
                } else {
                    onPick(IconRef(kind = "custom", value = encoded, mime = "image/png"))
                    onDismiss()
                }
            }
        }
    }
    val filtered = remember(icons, query) {
        icons.asSequence()
            .filter { query.isBlank() || it.name.contains(query, ignoreCase = true) }
            .take(160)
            .toList()
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text("选择图标") },
        text = {
            Column {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    placeholder = { Text("搜索图标名称") },
                    leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.small,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = { imagePicker.launch("image/*") }) {
                        Icon(
                            Icons.Outlined.AddPhotoAlternate,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(Modifier.width(6.dp))
                        Text("导入图片…")
                    }
                    imageError?.let {
                        Text(
                            it,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.padding(start = 4.dp),
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                when {
                    icons.isEmpty() -> Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 24.dp),
                        horizontalArrangement = Arrangement.Center,
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("正在读取内置图标…", style = MaterialTheme.typography.bodySmall)
                    }

                    filtered.isEmpty() -> Text(
                        "没有匹配的图标。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 16.dp),
                    )

                    else -> LazyColumn(modifier = Modifier.heightIn(max = 380.dp)) {
                        items(filtered.size, key = { filtered[it].filename }) { index ->
                            val icon = filtered[index]
                            val selected = current?.kind == "pack" && current.value == icon.filename
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        onPick(IconRef(kind = "pack", value = icon.filename, mime = "image/svg+xml"))
                                    }
                                    .padding(horizontal = 4.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                PackIconPreview(icon.filename, icon.name)
                                Spacer(Modifier.width(12.dp))
                                Text(
                                    text = icon.name,
                                    style = MaterialTheme.typography.bodyMedium,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.weight(1f),
                                )
                                if (selected) {
                                    Text(
                                        "已选",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.primary,
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
        dismissButton = {
            TextButton(
                onClick = {
                    onPick(null)
                    onDismiss()
                },
            ) { Text("使用字母头像") }
        },
    )
}

@Composable
fun PackIconPreview(filename: String, name: String, size: Int = 32) {
    val context = LocalContext.current
    val vector by produceState<ImageVector?>(null, filename) {
        value = withContext(Dispatchers.IO) {
            AegisIconPack.vectorFor(context, filename, name)
        }
    }
    val icon = vector
    if (icon == null) {
        LetterAvatar(title = name, size = size.dp)
    } else {
        androidx.compose.foundation.layout.Box(
            modifier = Modifier
                .size(size.dp)
                .background(
                    MaterialTheme.colorScheme.primaryContainer,
                    RoundedCornerShape((size * 0.3f).dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size((size * 0.62f).dp),
            )
        }
    }
}

private fun loadScaledIcon(context: Context, uri: Uri): String? {
    val input = context.contentResolver.openInputStream(uri) ?: return null
    val bitmap = input.use { BitmapFactory.decodeStream(it) } ?: return null
    val maxSide = maxOf(bitmap.width, bitmap.height)
    val scale = if (maxSide > 160) 160f / maxSide else 1f
    val scaled = if (scale < 1f) {
        Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * scale).toInt().coerceAtLeast(1),
            (bitmap.height * scale).toInt().coerceAtLeast(1),
            true,
        )
    } else {
        bitmap
    }
    val output = ByteArrayOutputStream()
    scaled.compress(Bitmap.CompressFormat.PNG, 100, output)
    return Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
}
