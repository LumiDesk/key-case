import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/crypto/kdf.dart';
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
      VaultItem(
        id: 'item-$title',
        kind: ItemKind.login,
        title: title,
        username: 'user',
        password: 'pass',
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
}
