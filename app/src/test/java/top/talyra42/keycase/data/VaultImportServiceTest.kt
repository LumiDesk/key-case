package top.talyra42.keycase.data

import org.junit.Assert.assertEquals
import org.junit.Test
import top.talyra42.keycase.core.importing.AegisImportResult
import top.talyra42.keycase.core.model.HashAlgorithm
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.OtpType
import top.talyra42.keycase.core.model.TotpSecret
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.model.VaultGroup
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.core.otp.ParsedOtp

class VaultImportServiceTest {
    private fun emptyVault() = VaultData(vaultId = "v", createdAt = "2026-01-01T00:00:00Z")

    private fun parsed(secret: String, issuer: String = "Example") = ParsedOtp(
        type = OtpType.TOTP,
        issuer = issuer,
        account = "user",
        secret = secret,
        algorithm = HashAlgorithm.SHA1,
        digits = 6,
        period = 30,
        counter = 0,
    )

    private fun item(id: String, secret: String, groupIds: List<String> = emptyList()) = VaultItem(
        id = id,
        kind = ItemKind.TOTP,
        title = "Example",
        totp = TotpSecret(secret = secret),
        groupIds = groupIds,
    )

    @Test
    fun googleImportSkipsExistingSecrets() {
        val current = emptyVault().copy(items = listOf(item("a", "AAAA")))
        val result = VaultImportService.mergeGoogle(
            current,
            listOf(parsed("AAAA"), parsed("BBBB")),
        )

        assertEquals(1, result.imported)
        assertEquals(1, result.skippedDuplicates)
        assertEquals(2, result.data.items.size)
        assertEquals("BBBB", result.data.items.last().totp?.secret)
    }

    @Test
    fun aegisReusesExistingGroupAndDropsDuplicateTokens() {
        val current = emptyVault().copy(
            groups = listOf(VaultGroup(id = "existing", name = "Work")),
            items = listOf(item("a", "AAAA")),
        )
        val importedGroup = VaultGroup(id = "imported", name = "work")
        val result = VaultImportService.mergeAegis(
            current,
            AegisImportResult(
                items = listOf(
                    item("b", "AAAA", groupIds = listOf("imported")),
                    item("c", "CCCC", groupIds = listOf("imported")),
                ),
                groups = listOf(importedGroup),
                skipped = 0,
            ),
        )

        assertEquals(1, result.imported)
        assertEquals(1, result.skippedDuplicates)
        assertEquals(2, result.data.items.size)
        assertEquals(1, result.data.groups.size)
        assertEquals(listOf("existing"), result.data.items.last().groupIds)
    }
}
