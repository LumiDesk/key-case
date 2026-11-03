import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/keycase_state.dart';
import 'package:keycase/app/models/models.dart';

void main() {
  KeyCaseState unlockedState() {
    return KeyCaseState(
      status: VaultStatus.unlocked,
      data: VaultData(
        vaultId: 'vault-id',
        createdAt: DateTime.utc(2026),
        items: <VaultItem>[
          VaultItem.loginItem(
            id: 'item',
            title: 'Example',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
  }

  test('锁定状态丢弃解密后的条目', () {
    final locked = unlockedState().copyWith(
      status: VaultStatus.locked,
      clearData: true,
    );

    expect(locked.status, VaultStatus.locked);
    expect(locked.data, isNull);
    expect(locked.isUnlocked, isFalse);
    expect(locked.activeItems, isEmpty);
  });

  test('普通状态更新保留条目', () {
    final next = unlockedState().copyWith(busy: true);

    expect(next.data, isNotNull);
    expect(next.activeItems, hasLength(1));
  });
}
