package top.talyra42.keycase.data

import android.content.Context
import androidx.core.util.AtomicFile
import java.io.File

/**
 * The vault lives in app-private storage. Writes go through AtomicFile so a
 * crash cannot leave a half-written vault behind.
 */
class AndroidVaultStore(context: Context) {
    private val file = AtomicFile(File(context.filesDir, FILE_NAME))

    fun exists(): Boolean = file.baseFile.isFile

    fun read(): ByteArray = file.readFully()

    fun write(bytes: ByteArray) {
        val out = file.startWrite()
        try {
            out.write(bytes)
            out.flush()
            file.finishWrite(out)
        } catch (e: Exception) {
            file.failWrite(out)
            throw e
        }
    }

    fun delete() {
        file.delete()
    }

    /**
     * Keeps the current ciphertext as a safety copy before destructive
     * operations such as importing another vault. The copy stays encrypted.
     */
    fun backupBeforeImport(): File {
        val source = file.baseFile
        check(source.isFile) { "No vault to back up" }
        val target = File(source.parentFile, "$FILE_NAME.pre-import")
        source.copyTo(target, overwrite = true)
        return target
    }

    companion object {
        const val FILE_NAME = "vault.tkv"
    }
}
