package top.talyra42.keycase.core.vault

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import top.talyra42.keycase.core.crypto.KdfParams
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.TotpSecret
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.model.VaultGroup
import top.talyra42.keycase.core.model.VaultItem

class VaultContainerTest {
    private val fastKdf = KdfParams(memoryKib = 1024, iterations = 1, parallelism = 1)
    private val password = "correct horse battery staple".toCharArray()

    private fun sampleVault() = VaultData(
        vaultId = "",
        createdAt = "",
        groups = listOf(VaultGroup(id = "g1", name = "Work")),
        items = listOf(
            VaultItem(
                id = "i1",
                kind = ItemKind.LOGIN,
                title = "GitHub",
                username = "lin.dev",
                password = "s3cret",
                urls = listOf("https://github.com"),
                groupIds = listOf("g1"),
                totp = TotpSecret(secret = "JBSWY3DPEHPK3PXP"),
            ),
        ),
    )

    @Test
    fun roundTripPreservesPayload() {
        val original = sampleVault()
        val bytes = VaultContainer.create(password, original, fastKdf)

        val opened = VaultContainer.open(password, bytes)

        assertEquals(original.items, opened.items)
        assertEquals(original.groups, opened.groups)
        assertEquals(1, opened.schema)
        assertEquals(VaultContainer.FORMAT_VERSION, VaultContainer.inspect(bytes).formatVersion)
    }

    @Test
    fun wrongPasswordFails() {
        val bytes = VaultContainer.create(password, sampleVault(), fastKdf)

        assertThrows(VaultFormatException::class.java) {
            VaultContainer.open("wrong password".toCharArray(), bytes)
        }
    }

    @Test
    fun tamperedPayloadFails() {
        val bytes = VaultContainer.create(password, sampleVault(), fastKdf)
        bytes[bytes.lastIndex] = (bytes.last().toInt() xor 0x01).toByte()

        assertThrows(VaultFormatException::class.java) {
            VaultContainer.open(password, bytes)
        }
    }

    @Test
    fun badMagicFails() {
        val bytes = VaultContainer.create(password, sampleVault(), fastKdf)
        bytes[0] = 'X'.code.toByte()

        assertThrows(VaultFormatException::class.java) {
            VaultContainer.inspect(bytes)
        }
    }

    @Test
    fun createSessionAvoidsSecondUnlock() {
        val created = VaultContainer.createSession(password, sampleVault(), fastKdf)

        assertEquals("GitHub", created.session.data.items.first().title)
        assertEquals(
            created.session.data.items,
            VaultContainer.open(password, created.bytes).items,
        )
    }

    @Test
    fun unlockWithVaultKeyOpensSameData() {
        val created = VaultContainer.createSession(password, sampleVault(), fastKdf)
        val reopened = VaultContainer.unlockWithVaultKey(created.bytes, created.session.vaultKey)
        try {
            assertEquals("GitHub", reopened.data.items.first().title)
        } finally {
            reopened.close()
            created.session.close()
        }
    }

    @Test
    fun sealPersistsEditsWithoutReenteringPassword() {        val bytes = VaultContainer.create(password, sampleVault(), fastKdf)
        val session = VaultContainer.unlock(password, bytes)
        val edited = session.data.copy(
            items = session.data.items + VaultItem(
                id = "i2",
                kind = ItemKind.TOTP,
                title = "GitHub",
                username = "lin.dev",
                totp = TotpSecret(secret = "JBSWY3DPEHPK3PXP"),
            ),
        )

        val resealed = VaultContainer.seal(session.withData(edited))
        val reopened = VaultContainer.open(password, resealed)

        assertEquals(2, reopened.items.size)
        assertEquals("i2", reopened.items.last().id)
    }

    @Test
    fun changePasswordRotatesOnlyPasswordSlot() {
        val bytes = VaultContainer.create(password, sampleVault(), fastKdf)
        val session = VaultContainer.unlock(password, bytes)
        val newPassword = "a new master password".toCharArray()

        val rotated = VaultContainer.changePasswordSession(session, newPassword, fastKdf)

        assertThrows(VaultFormatException::class.java) {
            VaultContainer.open(password, rotated.bytes)
        }
        val reopened = VaultContainer.open(newPassword, rotated.bytes)
        assertEquals(session.data.items, reopened.items)
        assertEquals(session.data.items, rotated.session.data.items)
        assertEquals(1, VaultContainer.inspect(rotated.bytes).slots.count { it.type == "password" })
    }
}
