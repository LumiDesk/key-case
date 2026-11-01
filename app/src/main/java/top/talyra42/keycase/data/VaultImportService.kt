package top.talyra42.keycase.data

import top.talyra42.keycase.core.importing.AegisImportResult
import top.talyra42.keycase.core.model.ItemKind
import top.talyra42.keycase.core.model.TotpSecret
import top.talyra42.keycase.core.model.VaultData
import top.talyra42.keycase.core.model.VaultItem
import top.talyra42.keycase.core.otp.ParsedOtp
import java.time.Instant
import java.util.UUID

data class ImportMergeResult(
    val data: VaultData,
    val imported: Int,
    val skippedDuplicates: Int,
)

/**
 * Pure merge rules for imported tokens. Kept out of the ViewModel so duplicate
 * handling and group reconciliation are unit-testable.
 */
object VaultImportService {
    fun mergeGoogle(
        current: VaultData,
        parsed: List<ParsedOtp>,
        now: String = Instant.now().toString(),
    ): ImportMergeResult {
        val existingSecrets = current.items.mapNotNull { it.totp?.secret }.toMutableSet()
        val unique = parsed.filter { existingSecrets.add(it.secret) }
        val items = unique.map { otp ->
            VaultItem(
                id = UUID.randomUUID().toString(),
                kind = ItemKind.TOTP,
                title = otp.issuer.ifBlank { otp.account }.ifBlank { "动态令牌" },
                issuer = otp.issuer,
                username = otp.account,
                totp = TotpSecret(
                    type = otp.type,
                    secret = otp.secret,
                    algorithm = otp.algorithm,
                    digits = otp.digits,
                    period = otp.period,
                    counter = otp.counter,
                ),
                createdAt = now,
                updatedAt = now,
            )
        }
        return ImportMergeResult(
            data = current.copy(items = current.items + items),
            imported = items.size,
            skippedDuplicates = parsed.size - unique.size,
        )
    }

    fun mergeAegis(current: VaultData, result: AegisImportResult): ImportMergeResult {
        val existingSecrets = current.items.mapNotNull { it.totp?.secret }.toMutableSet()
        val uniqueItems = result.items.filter { item ->
            item.totp?.secret?.let { existingSecrets.add(it) } ?: true
        }

        val groups = current.groups.toMutableList()
        val groupIdMap = mutableMapOf<String, String>()
        result.groups.forEach { importedGroup ->
            val existing = groups.firstOrNull {
                it.name.equals(importedGroup.name, ignoreCase = true)
            }
            val target = existing ?: importedGroup.copy(id = UUID.randomUUID().toString())
                .also { groups.add(it) }
            groupIdMap[importedGroup.id] = target.id
        }
        val importedItems = uniqueItems.map { item ->
            item.copy(groupIds = item.groupIds.mapNotNull { groupIdMap[it] })
        }
        return ImportMergeResult(
            data = current.copy(groups = groups, items = current.items + importedItems),
            imported = importedItems.size,
            skippedDuplicates = result.items.size - uniqueItems.size,
        )
    }
}
