package top.talyra42.keycase.core.importing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AegisImporterTest {
    private fun resource(name: String): ByteArray =
        javaClass.classLoader!!.getResourceAsStream(name)!!.readBytes()

    @Test
    fun importsPlainAegisExport() {
        val result = AegisImporter.import(resource("aegis_plain.json"))

        assertTrue(result.items.isNotEmpty())
        assertEquals(0, result.skipped)
        val first = result.items.first()
        assertEquals("Deno", first.title)
        assertEquals("Mason", first.username)
        assertEquals("4SJHB4GSD43FZBAI7C2HLRJGPQ", first.totp?.secret)
    }

    @Test
    fun importsEncryptedAegisExport() {
        val result = AegisImporter.import(
            resource("aegis_encrypted.json"),
            "test".toCharArray(),
        )

        assertTrue(result.items.isNotEmpty())
        assertEquals(0, result.skipped)
    }

    @Test
    fun rejectsWrongAegisPassword() {
        assertThrows(AegisImportException::class.java) {
            AegisImporter.import(
                resource("aegis_encrypted.json"),
                "wrong".toCharArray(),
            )
        }
    }
}
