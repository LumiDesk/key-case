package top.talyra42.keycase.ui

import android.content.Context
import android.net.Uri
import android.util.Base64
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import top.talyra42.keycase.ui.icons.ImportedIconPack
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

@RunWith(AndroidJUnit4::class)
class ImportedIconPackTest {
    @Test
    fun importsBitmapPackAndEncodesSelection() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val zip = File(context.cacheDir, "test-icon-pack.zip")
        val png = Base64.decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
            Base64.DEFAULT,
        )
        ZipOutputStream(zip.outputStream()).use { out ->
            out.putNextEntry(ZipEntry("pack.json"))
            out.write(
                """{"name":"Test pack","icons":[{"name":"GitHub","filename":"github.png","issuer":["GitHub"]}]}"""
                    .toByteArray(),
            )
            out.closeEntry()
            out.putNextEntry(ZipEntry("icons/github.png"))
            out.write(png)
            out.closeEntry()
        }

        val result = ImportedIconPack.import(context, Uri.fromFile(zip))
        assertEquals(1, result.imported)
        val icon = ImportedIconPack.list(context).first { it.name == "GitHub" }
        assertTrue(icon.file.isFile)
        assertTrue(ImportedIconPack.encodeForVault(icon.file).isNotBlank())
    }
}
