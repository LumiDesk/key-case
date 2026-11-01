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

    @Test
    fun rejectsScryptParametersThatWouldExhaustMemory() {
        val zeros32 = "00".repeat(32)
        val nonce = "00".repeat(12)
        val tag = "00".repeat(16)
        val json = """
            {
              "version": 1,
              "header": {
                "slots": [{
                  "type": 1,
                  "key": "$zeros32",
                  "key_params": {"nonce": "$nonce", "tag": "$tag"},
                  "n": 1048576,
                  "r": 32,
                  "p": 1,
                  "salt": "$zeros32"
                }],
                "params": {"nonce": "$nonce", "tag": "$tag"}
              },
              "db": "AAAA"
            }
        """.trimIndent()

        assertThrows(AegisImportException::class.java) {
            AegisImporter.import(json.toByteArray(), "test".toCharArray())
        }
    }
}
