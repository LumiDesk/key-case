package top.talyra42.keycase.ui

import androidx.compose.ui.res.stringResource

import top.talyra42.keycase.R

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.UploadFile
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import top.talyra42.keycase.core.model.IconRef
import top.talyra42.keycase.ui.icons.AegisIconPack
import top.talyra42.keycase.ui.icons.ImportedIconPack
import java.io.ByteArrayOutputStream
import androidx.compose.runtime.rememberCoroutineScope

@Composable
fun IconPickerDialog(
    current: IconRef?,
    onDismiss: () -> Unit,
    onPick: (IconRef?) -> Unit,
    onPrepareExternal: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val icons by produceState<List<AegisIconPack.PackIcon>>(emptyList()) {
        value = withContext(Dispatchers.IO) { AegisIconPack.entries(context) }
    }
    var packReload by remember { mutableIntStateOf(0) }
    val importedIcons by produceState<List<ImportedIconPack.PackIcon>>(
        initialValue = emptyList(),
        packReload,
    ) {
        value = withContext(Dispatchers.IO) { ImportedIconPack.list(context) }
    }
    var query by rememberSaveable { mutableStateOf("") }
    var imageError by remember { mutableStateOf<String?>(null) }
    var packStatus by remember { mutableStateOf<String?>(null) }
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
    val packPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            scope.launch {
                withContext(Dispatchers.IO) {
                    runCatching { ImportedIconPack.import(context, uri) }
                }.onSuccess { result ->
                    packReload++
                    packStatus = "已导入 ${result.imported} 个图标"
                }.onFailure {
                    imageError = it.message ?: "无法读取图标包"
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
    val filteredImported = remember(importedIcons, query) {
        importedIcons.asSequence()
            .filter {
                query.isBlank() ||
                    it.name.contains(query, ignoreCase = true) ||
                    it.issuer.orEmpty().contains(query, ignoreCase = true)
            }
            .take(160)
            .toList()
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surface,
        title = { Text(stringResource(R.string.s_ef6e0d1008d0)) },
        text = {
            Column {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    placeholder = { Text(stringResource(R.string.s_6d0a2ce75c15)) },
                    leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = MaterialTheme.shapes.small,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = {
                        onPrepareExternal()
                        imagePicker.launch("image/*")
                    }) {
                        Icon(
                            Icons.Outlined.AddPhotoAlternate,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(stringResource(R.string.s_a8aea3361e6a))
                    }
                    TextButton(onClick = {
                        onPrepareExternal()
                        packPicker.launch("*/*")
                    }) {
                        Icon(
                            Icons.Outlined.UploadFile,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(stringResource(R.string.s_2c4d3f41834c))
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
                packStatus?.let {
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(bottom = 4.dp),
                    )
                }
                Spacer(Modifier.height(8.dp))
                when {
                    icons.isEmpty() && importedIcons.isEmpty() -> Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 24.dp),
                        horizontalArrangement = Arrangement.Center,
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(stringResource(R.string.s_23a403fd6ab6), style = MaterialTheme.typography.bodySmall)
                    }

                    filtered.isEmpty() && filteredImported.isEmpty() -> Text(
                        stringResource(R.string.s_21d9f4a8d74f),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 16.dp),
                    )

                    else -> LazyColumn(modifier = Modifier.heightIn(max = 380.dp)) {
                        if (filteredImported.isNotEmpty()) {
                            item {
                                Text(
                                    stringResource(R.string.s_efeffa950e10),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(vertical = 4.dp),
                                )
                            }
                            val grouped = filteredImported.groupBy { it.packName }
                            grouped.forEach { (packName, packIcons) ->
                                item(key = "imported-pack-$packName") {
                                    Text(
                                        "$packName · ${packIcons.size}",
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.padding(top = 4.dp, bottom = 2.dp),
                                    )
                                }
                                items(packIcons, key = { it.file.absolutePath }) { icon ->
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable {
                                                scope.launch {
                                                    runCatching {
                                                        withContext(Dispatchers.IO) {
                                                            ImportedIconPack.encodeForVault(icon.file)
                                                        }
                                                    }.onSuccess { encoded ->
                                                        onPick(
                                                            IconRef(
                                                                kind = "custom",
                                                                value = encoded,
                                                                mime = "image/png",
                                                            ),
                                                        )
                                                        onDismiss()
                                                    }.onFailure {
                                                        imageError = it.message ?: "无法读取图标"
                                                    }
                                                }
                                            }
                                            .padding(horizontal = 4.dp, vertical = 8.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        ImportedIconPreview(icon.file)
                                        Spacer(Modifier.width(12.dp))
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(
                                                text = icon.name,
                                                style = MaterialTheme.typography.bodyMedium,
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis,
                                            )
                                            icon.issuer?.let {
                                                Text(
                                                    text = it,
                                                    style = MaterialTheme.typography.labelSmall,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                    maxLines = 1,
                                                    overflow = TextOverflow.Ellipsis,
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            item { HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp)) }
                        }
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
                                        stringResource(R.string.s_f24ddc2bef8f),
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
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.s_33246f6a5e5b)) }
        },
        dismissButton = {
            TextButton(
                onClick = {
                    onPick(null)
                    onDismiss()
                },
            ) { Text(stringResource(R.string.s_2971225c3452)) }
        },
    )
}

@Composable
fun ImportedIconPreview(file: java.io.File, size: Int = 32) {
    val bitmap by produceState<androidx.compose.ui.graphics.ImageBitmap?>(
        initialValue = top.talyra42.keycase.ui.icons.IconBitmapCache.get(
            "file:${file.absolutePath}:96",
        ),
        file.absolutePath,
    ) {
        value = withContext(Dispatchers.IO) {
            top.talyra42.keycase.ui.icons.IconBitmapCache.decodeFile(file)
        }
    }
    val image = bitmap
    if (image == null) {
        LetterAvatar(title = file.nameWithoutExtension, size = size.dp)
    } else {
        Image(
            bitmap = image,
            contentDescription = null,
            modifier = Modifier.size(size.dp),
        )
    }
}

@Composable
fun PackIconPreview(filename: String, name: String, size: Int = 32) {
    val context = LocalContext.current
    var image by remember(filename) {
        mutableStateOf(top.talyra42.keycase.ui.icons.IconBitmapCache.get("svg:$filename:96"))
    }
    var loading by remember(filename) { mutableStateOf(image == null) }
    LaunchedEffect(filename) {
        if (image == null) {
            image = withContext(Dispatchers.IO) {
                AegisIconPack.bitmapFor(context, filename, maxSize = 96)
            }
        }
        loading = false
    }
    if (loading) {
        androidx.compose.foundation.layout.Box(
            modifier = Modifier
                .size(size.dp)
                .background(
                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                    RoundedCornerShape((size * 0.3f).dp),
                ),
        )
    } else if (image == null) {
        LetterAvatar(title = name, size = size.dp)
    } else {
        Image(
            bitmap = image!!,
            contentDescription = null,
            contentScale = androidx.compose.ui.layout.ContentScale.Fit,
            modifier = Modifier.size(size.dp),
        )
    }
}

private fun loadScaledIcon(context: Context, uri: Uri): String? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    context.contentResolver.openInputStream(uri)?.use {
        BitmapFactory.decodeStream(it, null, bounds)
    } ?: return null
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

    val options = BitmapFactory.Options().apply {
        inSampleSize = imageSampleSize(bounds.outWidth, bounds.outHeight, 160)
        inPreferredConfig = Bitmap.Config.ARGB_8888
    }
    val bitmap = context.contentResolver.openInputStream(uri)?.use {
        BitmapFactory.decodeStream(it, null, options)
    } ?: return null

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

private fun imageSampleSize(width: Int, height: Int, maxSide: Int): Int {
    var sample = 1
    while (maxOf(width, height) / (sample * 2) >= maxSide) {
        sample *= 2
    }
    return sample
}
