import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/crypto/aead.dart';
import 'package:keycase/app/crypto/kdf.dart';
import 'package:keycase/app/crypto/random.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/vault/vault_container.dart';
import 'package:keycase/app/vault/vault_repository.dart';
import 'package:path/path.dart' as p;

const KdfParams testKdf = KdfParams(
  memoryKib: 64,
  iterations: 1,
  parallelism: 1,
);

VaultData dataWithItem(String title) {
  final now = DateTime.utc(2026, 1, 1);
  return VaultData(
    vaultId: '',
    createdAt: now,
    items: <VaultItem>[
      VaultItem.loginItem(
        id: 'item-$title',
        title: title,
        login: const LoginData(username: 'user', password: 'pass'),
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}

void main() {
  late Directory directory;
  late VaultRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('keycase-test-');
    repository = VaultRepository(directory: directory, kdfParams: testKdf);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('创建、存在性、解锁与保存', () async {
    final created = await repository.create(
      password: 'password-1',
      data: dataWithItem('GitHub'),
    );
    expect(await repository.exists(), isTrue);
    expect(created.data.items.single.title, 'GitHub');

    final unlocked = await repository.unlock('password-1');
    expect(unlocked.data.items.single.title, 'GitHub');
    expect(repository.isUnlocked, isTrue);

    final saved = await repository.save(
      created.data.copyWith(items: dataWithItem('Updated').items),
    );
    expect(saved, isNotEmpty);
    expect(repository.currentData?.items.single.title, 'Updated');
    expect(
      File(p.join(directory.path, '${VaultRepository.fileName}.tmp'))
          .existsSync(),
      isFalse,
    );

    final again = await repository.unlock('password-1');
    expect(again.data.items.single.title, 'Updated');
  });

  test('错误口令与锁定会话', () async {
    await repository.create(
      password: 'right-password',
      data: dataWithItem('GitHub'),
    );

    await expectLater(
      repository.unlock('wrong-password'),
      throwsA(isA<VaultFormatException>()),
    );

    repository.lock();
    expect(repository.session, isNull);
    expect(repository.isUnlocked, isFalse);
  });

  test('改主密码后旧口令失效、新口令可用', () async {
    await repository.create(
      password: 'old-password',
      data: dataWithItem('GitHub'),
    );

    await repository.changePassword(
      currentPassword: 'old-password',
      newPassword: 'new-password',
    );

    await expectLater(
      repository.unlock('old-password'),
      throwsA(isA<VaultFormatException>()),
    );
    final unlocked = await repository.unlock('new-password');
    expect(unlocked.data.items.single.title, 'GitHub');
  });

  test('用备份替换时保留 pre-import 副本', () async {
    await repository.create(
      password: 'original',
      data: dataWithItem('Original'),
    );
    final replacement = await VaultContainer.create(
      password: 'replacement',
      data: dataWithItem('Replacement'),
      kdfParams: testKdf,
    );

    final session = await repository.replaceWithBackup(
      bytes: replacement.bytes,
      password: 'replacement',
    );

    expect(session.data.items.single.title, 'Replacement');
    expect(
      File(p.join(directory.path, VaultRepository.preImportFileName))
          .existsSync(),
      isTrue,
    );
  });

  test('inspect 只读容器头，deleteAll 删除库与副本', () async {
    await repository.create(password: 'password', data: dataWithItem('GitHub'));
    final header = await repository.inspect();
    expect(header, isNotNull);
    expect(header!.formatVersion, VaultContainer.formatVersion);

    await File(p.join(directory.path, VaultRepository.preImportFileName))
        .writeAsBytes(Uint8List.fromList(<int>[1]));
    await repository.deleteAll();

    expect(await repository.exists(), isFalse);
    expect(
      File(p.join(directory.path, VaultRepository.preImportFileName))
          .existsSync(),
      isFalse,
    );
    expect(repository.session, isNull);
  });

  test('并发保存按顺序串行落盘', () async {
    await repository.create(password: 'password', data: dataWithItem('First'));

    final base = repository.currentData!;
    final first = repository.save(
      base.copyWith(items: dataWithItem('First-saved').items),
    );
    final second = repository.save(
      base.copyWith(items: dataWithItem('Second-saved').items),
    );
    await Future.wait(<Future<Uint8List>>[first, second]);

    final unlocked = await repository.unlock('password');
    expect(unlocked.data.items.single.title, 'Second-saved');
  });

  test('旧版 v1 库被拒绝且不产生会话', () async {
    const vaultId = 'legacy-vault';
    final now = DateTime.utc(2026, 1, 1);
    final v1Bytes = await _buildV1Vault(
      password: 'password',
      vaultId: vaultId,
      now: now,
    );
    await File(p.join(directory.path, VaultRepository.fileName))
        .writeAsBytes(v1Bytes);

    await expectLater(
      repository.unlock('password'),
      throwsA(
        isA<VaultFormatException>().having(
          (error) => error.code,
          'code',
          VaultErrorCode.unsupportedVersion,
        ),
      ),
    );
    expect(repository.session, isNull);
  });

  test('保存过程中锁定：不写回、不复活会话', () async {
    final gated = _GatedRepository(directory: directory);
    await gated.create(password: 'password', data: dataWithItem('Before'));
    gated.block = true;

    final saving = gated.save(
      gated.currentData!.copyWith(items: dataWithItem('After').items),
    );
    await Future<void>.delayed(Duration.zero);
    gated.lock();
    gated.gate.complete();

    await expectLater(saving, throwsA(isA<VaultFormatException>()));
    expect(gated.isUnlocked, isFalse);
    expect(gated.session, isNull);
  });
}

class _GatedRepository extends VaultRepository {
  _GatedRepository({required Directory directory})
    : super(directory: directory, kdfParams: testKdf);

  final Completer<void> gate = Completer<void>();
  bool block = false;

  @override
  Future<Uint8List> sealSession(UnlockedVault session) async {
    if (block) await gate.future;
    return super.sealSession(session);
  }
}

/// 按旧格式手工组装一个 KCV1 容器，用来验证旧版本被拒绝。
Future<Uint8List> _buildV1Vault({
  required String password,
  required String vaultId,
  required DateTime now,
}) async {
  final vaultKey = randomBytes(32);
  final salt = randomBytes(16);
  final slotId = newId();
  final passwordKey = await deriveArgon2idKey(
    password: password,
    salt: salt,
    params: testKdf,
  );
  final wrapped = await sealBytes(
    key: passwordKey,
    plaintext: vaultKey,
    aad: utf8.encode('KCV1|1|$slotId|password'),
  );
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'vaultId': vaultId,
    'createdAt': now.toIso8601String(),
    'items': <Object?>[
      <String, Object?>{
        'id': 'legacy-login',
        'kind': 'login',
        'title': 'Legacy',
        'username': 'alice',
        'password': 'secret',
        'urls': <String>['https://example.com'],
        'notes': 'note',
        'favorite': true,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      },
      <String, Object?>{
        'id': 'legacy-token',
        'kind': 'totp',
        'title': 'Legacy Token',
        'username': 'alice',
        'totp': <String, Object?>{
          'type': 'totp',
          'secret': 'JBSWY3DPEHPK3PXP',
          'algorithm': 'SHA1',
          'digits': 6,
          'period': 30,
          'counter': 0,
        },
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      },
    ],
  };
  final compressed = GZipEncoder().encode(utf8.encode(jsonEncode(payload)));
  final sealed = await sealBytes(
    key: vaultKey,
    plaintext: Uint8List.fromList(compressed),
    aad: utf8.encode('KCV1|1|$vaultId|payload'),
  );
  final header = <String, Object?>{
    'formatVersion': 1,
    'vaultId': vaultId,
    'createdAt': now.toIso8601String(),
    'kdf': testKdf.toJson(),
    'slots': <Object?>[
      <String, Object?>{
        'id': slotId,
        'type': VaultContainer.passwordSlotType,
        'salt': base64Encode(salt),
        'nonce': base64Encode(wrapped.nonce),
        'wrappedKey': base64Encode(wrapped.cipherText),
      },
    ],
    'payloadNonce': base64Encode(sealed.nonce),
  };
  final headerBytes = utf8.encode(jsonEncode(header));
  final out = Uint8List(9 + headerBytes.length + sealed.cipherText.length);
  out.setAll(0, ascii.encode(VaultContainer.magic));
  out[4] = VaultContainer.formatVersion;
  ByteData.sublistView(out, 5, 9).setUint32(0, headerBytes.length);
  out.setAll(9, headerBytes);
  out.setAll(9 + headerBytes.length, sealed.cipherText);
  return out;
}
