import '../models/models.dart';

/// 列表排序方式。只影响展示，不落库。
enum ItemSort { name, recent, favoritesFirst }

List<VaultItem> sortItems(Iterable<VaultItem> items, ItemSort sort) {
  final list = items.toList();
  switch (sort) {
    case ItemSort.name:
      list.sort(_byTitle);
    case ItemSort.recent:
      list.sort((a, b) {
        final byDate = b.updatedAt.compareTo(a.updatedAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    case ItemSort.favoritesFirst:
      list.sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return _byTitle(a, b);
      });
  }
  return list;
}

int _byTitle(VaultItem a, VaultItem b) {
  final byTitle = a.displayTitle.toLowerCase().compareTo(
    b.displayTitle.toLowerCase(),
  );
  return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
}

/// 首字母分组键：A–Z 用大写字母，其余（中文、数字、符号）统一进 `#`。
String initialOf(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return '#';
  final first = String.fromCharCode(trimmed.runes.first).toUpperCase();
  if (RegExp(r'^[A-Z]$').hasMatch(first)) return first;
  return '#';
}

/// 按首字母分组，组内已排序，`#` 永远在最后。
List<({String letter, List<VaultItem> items})> groupByInitial(
  Iterable<VaultItem> items,
) {
  final groups = <String, List<VaultItem>>{};
  for (final item in items) {
    groups
        .putIfAbsent(initialOf(item.displayTitle), () => <VaultItem>[])
        .add(item);
  }
  final letters = groups.keys.toList()
    ..sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });
  return <({String letter, List<VaultItem> items})>[
    for (final letter in letters) (letter: letter, items: groups[letter]!),
  ];
}

/// 全局搜索：名称、账号、网址、备注、服务名。
List<VaultItem> searchItems(Iterable<VaultItem> items, String query) {
  final text = query.trim().toLowerCase();
  if (text.isEmpty) return const <VaultItem>[];
  bool matches(String? value) =>
      value != null && value.toLowerCase().contains(text);
  return items
      .where(
        (item) =>
            matches(item.title) ||
            matches(item.username) ||
            matches(item.notes) ||
            item.urls.any(matches),
      )
      .toList(growable: false);
}
