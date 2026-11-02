import '../models/models.dart';

class ImportMergeResult {
  const ImportMergeResult({
    required this.data,
    required this.imported,
    required this.skippedDuplicates,
  });

  final VaultData data;
  final int imported;
  final int skippedDuplicates;
}

/// 把导入的条目合并进现有保险库。
///
/// 去重口径：令牌看「密钥 + 标题」，登录项看「标题 + 账号」。
/// 不看 id——导入方生成的 id 与本库无关，用内容判断才不会重复导入同一份备份。
ImportMergeResult mergeImportedItems(
  VaultData existing,
  List<VaultItem> imported,
) {
  final seen = <String>{for (final item in existing.items) _dedupeKey(item)};
  final merged = <VaultItem>[...existing.items];
  var added = 0;
  var duplicates = 0;

  for (final item in imported) {
    final key = _dedupeKey(item);
    if (!seen.add(key)) {
      duplicates++;
      continue;
    }
    merged.add(item);
    added++;
  }

  return ImportMergeResult(
    data: existing.copyWith(items: merged),
    imported: added,
    skippedDuplicates: duplicates,
  );
}

String _dedupeKey(VaultItem item) {
  if (item.isToken) {
    final secret = item.totp?.secret ?? '';
    return 'totp|${item.title.toLowerCase()}|$secret';
  }
  return 'login|${item.title.toLowerCase()}|${item.username.toLowerCase()}';
}
