import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/crypto/kdf.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/vault/vault_container.dart';

// 测试用低成本 KDF 参数：真实默认值在设备上要几百毫秒，单元测试不背这个成本。
const KdfParams testKdf = KdfParams(
  memoryKib: 64,
  iterations: 1,
  parallelism: 1,
);

VaultData emptyVault() =>
    VaultData(vaultId: '', createdAt: DateTime.utc(2026, 1, 1));

VaultItem item({String title = 'GitHub', String id = 'item-1'}) =>
    VaultItem.loginItem(
      id: id,
      title: title,
      login: const LoginData(
        username: 'user@example.com',
        password: 'p@ssw0rd',
        urls: <String>['https://github.com'],
      ),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );

void main() {
  group('VaultContainer', () {
    test('创建后用同一口令可以解锁并读回条目', () async {
      final created = await VaultContainer.create(
        password: 'correct horse battery staple',
        data: emptyVault().copyWith(items: <VaultItem>[item()]),
        kdfParams: testKdf,
      );

      final unlocked = await VaultContainer.unlock(
        password: 'correct horse battery staple',
        bytes: created.bytes,
      );

      expect(unlocked.data.items, hasLength(1));
      expect(unlocked.data.items.single.title, 'GitHub');
      expect(unlocked.data.items.single.password, 'p@ssw0rd');
      expect(unlocked.data.vaultId, created.session.header.vaultId);
      expect(unlocked.data.vaultId, isNotEmpty);
    });

    test('错误口令抛 VaultFormatException', () async {
      final created = await VaultContainer.create(
        password: 'right',
        data: emptyVault(),
        kdfParams: testKdf,
      );
      await expectLater(
        VaultContainer.unlock(password: 'wrong', bytes: created.bytes),
        throwsA(isA<VaultFormatException>()),
      );
    });

    test('篡改正文会认证失败', () async {
      final created = await VaultContainer.create(
        password: 'right',
        data: emptyVault(),
        kdfParams: testKdf,
      );
      final tampered = Uint8List.fromList(created.bytes);
      tampered[tampered.length - 1] ^= 0xFF;
      await expectLater(
        VaultContainer.unlock(password: 'right', bytes: tampered),
        throwsA(isA<VaultFormatException>()),
      );
    });

    test('seal 后旧口令仍可解锁，且内容一致', () async {
      final created = await VaultContainer.create(
        password: 'right',
        data: emptyVault(),
        kdfParams: testKdf,
      );
      final updated = created.session.withData(
        created.session.data.copyWith(items: <VaultItem>[item()]),
      );
      final bytes = await VaultContainer.seal(updated);

      final unlocked = await VaultContainer.unlock(
        password: 'right',
        bytes: bytes,
      );
      expect(unlocked.data.items.single.title, 'GitHub');
      // 每次保存都换 nonce，因此同样的明文不会产生同样的密文。
      expect(bytes.length, isNot(created.bytes.length));
    });

    test('改主密码后旧口令失效、新口令可用', () async {
      final created = await VaultContainer.create(
        password: 'old-password',
        data: emptyVault().copyWith(items: <VaultItem>[item()]),
        kdfParams: testKdf,
      );

      final rotated = await VaultContainer.changePassword(
        session: created.session,
        newPassword: 'new-password',
        kdfParams: testKdf,
      );

      await expectLater(
        VaultContainer.unlock(password: 'old-password', bytes: rotated.bytes),
        throwsA(isA<VaultFormatException>()),
      );

      final unlocked = await VaultContainer.unlock(
        password: 'new-password',
        bytes: rotated.bytes,
      );
      expect(unlocked.data.items.single.title, 'GitHub');
      expect(unlocked.data.vaultId, created.session.header.vaultId);
    });

    test('用 vault key 直接解锁（生物识别路径）', () async {
      final created = await VaultContainer.create(
        password: 'right',
        data: emptyVault().copyWith(items: <VaultItem>[item()]),
        kdfParams: testKdf,
      );

      final unlocked = await VaultContainer.unlockWithVaultKey(
        bytes: created.bytes,
        vaultKey: created.session.vaultKey,
      );
      expect(unlocked.data.items.single.title, 'GitHub');
    });

    test('拒绝非法文件头', () async {
      await expectLater(
        VaultContainer.unlock(
          password: 'x',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
        throwsA(isA<VaultFormatException>()),
      );
    });

    test('条目 JSON 往返保持字段', () {
      final original = VaultItem.tokenItem(
        id: 'token-1',
        title: 'GitHub',
        token: const TokenData(
          secret: TotpSecret(secret: 'JBSWY3DPEHPK3PXP', digits: 8),
          account: 'user@example.com',
          notes: '备注',
        ),
        favorite: true,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      final restored = VaultItem.fromJson(original.toJson());
      expect(restored.title, original.title);
      expect(restored.totp?.secret, 'JBSWY3DPEHPK3PXP');
      expect(restored.totp?.digits, 8);
      expect(restored.favorite, isTrue);
      expect(restored.notes, '备注');
      expect(restored.createdAt, original.createdAt);
    });
  });
}
