import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/vault/vault_query.dart';

VaultItem item({
  required String id,
  required String title,
  String username = '',
  String notes = '',
  List<String> urls = const <String>[],
  bool favorite = false,
  int updatedDay = 1,
  String? deletedAt,
}) {
  final now = DateTime.utc(2026, 1, updatedDay);
  return VaultItem.loginItem(
    id: id,
    title: title,
    login: LoginData(username: username, notes: notes, urls: urls),
    favorite: favorite,
    createdAt: now,
    updatedAt: now,
    deletedAt: deletedAt == null ? null : now,
  );
}

void main() {
  group('排序', () {
    final items = <VaultItem>[
      item(id: 'b', title: 'beta', updatedDay: 3),
      item(id: 'a', title: 'Alpha', updatedDay: 1, favorite: true),
      item(id: 'c', title: 'gamma', updatedDay: 2),
    ];

    test('按名称忽略大小写', () {
      expect(
        sortItems(items, ItemSort.name).map((e) => e.id).toList(),
        <String>['a', 'b', 'c'],
      );
    });

    test('按最近更新', () {
      expect(
        sortItems(items, ItemSort.recent).map((e) => e.id).toList(),
        <String>['b', 'c', 'a'],
      );
    });

    test('收藏优先', () {
      expect(
        sortItems(items, ItemSort.favoritesFirst).map((e) => e.id).toList(),
        <String>['a', 'b', 'c'],
      );
    });
  });

  group('首字母分组', () {
    test('非字母进 # 且排最后', () {
      final groups = groupByInitial(<VaultItem>[
        item(id: '1', title: '招商银行'),
        item(id: '2', title: 'apple'),
        item(id: '3', title: '1Password'),
        item(id: '4', title: 'Banana'),
      ]);
      expect(groups.map((group) => group.letter).toList(), <String>[
        'A',
        'B',
        '#',
      ]);
      expect(groups.last.items, hasLength(2));
    });
  });

  group('搜索', () {
    final items = <VaultItem>[
      item(id: '1', title: 'GitHub', username: 'talyra42'),
      item(id: '2', title: 'Google', urls: <String>['https://mail.google.com']),
      item(id: '3', title: '银行', notes: '工资卡'),
    ];

    test('命中标题、账号、网址、备注', () {
      expect(searchItems(items, 'github').single.id, '1');
      expect(searchItems(items, 'talyra').single.id, '1');
      expect(searchItems(items, 'google').single.id, '2');
      expect(searchItems(items, '工资').single.id, '3');
    });

    test('空查询返回空集合，无匹配返回空', () {
      expect(searchItems(items, '  '), isEmpty);
      expect(searchItems(items, 'nothing'), isEmpty);
    });
  });
}
