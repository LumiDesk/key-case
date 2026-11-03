import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/vault/backup_service.dart';

import 'support/fakes.dart';

void main() {
  test('写入快照超过 10 份时删除最旧的文件', () async {
    final native = FakeNativeBridge()
      ..backupFiles = <String>[
        for (var i = 10; i >= 1; i--)
          'keycase-20260101-${i.toString().padLeft(6, '0')}.kcbak',
      ];
    final service = BackupService(bridge: native);

    final name = await service.writeSnapshot(
      dirUri: 'content://backup',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );

    expect(name, startsWith('keycase-'));
    expect(native.writtenNames, contains(name));
    expect(native.deletedNames, hasLength(1));
    expect(native.deletedNames.single, 'keycase-20260101-000001.kcbak');
    expect(native.backupFiles, hasLength(10));
  });

  test('轮转只删除 kcbak 快照，不动同目录其它文件', () async {
    final native = FakeNativeBridge()
      ..backupFiles = <String>[
        'notes.txt',
        for (var i = 10; i >= 1; i--)
          'keycase-20260101-${i.toString().padLeft(6, '0')}.kcbak',
      ];
    final service = BackupService(bridge: native);

    await service.writeSnapshot(
      dirUri: 'content://backup',
      bytes: Uint8List.fromList(<int>[1]),
    );

    expect(native.deletedNames, hasLength(1));
    expect(native.deletedNames.single, endsWith('.kcbak'));
    expect(native.backupFiles, contains('notes.txt'));
    expect(native.backupFiles, hasLength(11)); // 10 份快照 + notes.txt
  });

  test('写入失败抛出 FileSystemException', () async {
    final native = FakeNativeBridge()..backupWriteResult = false;
    final service = BackupService(bridge: native);

    await expectLater(
      service.writeSnapshot(
        dirUri: 'content://backup',
        bytes: Uint8List.fromList(<int>[1]),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('选择目录与列出快照委托给原生桥', () async {
    final native = FakeNativeBridge()
      ..folder = (uri: 'content://picked', name: 'KeyCase')
      ..backupFiles = <String>['b.kcbak', 'a.kcbak'];
    final service = BackupService(bridge: native);

    final folder = await service.pickFolder();
    final snapshots = await service.listSnapshots('content://picked');

    expect(folder?.uri, 'content://picked');
    expect(folder?.name, 'KeyCase');
    expect(snapshots, <String>['b.kcbak', 'a.kcbak']);
  });

  test('导出备份通过系统新建文档写入', () async {
    final native = FakeNativeBridge();
    final service = BackupService(bridge: native);
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    final name = await service.exportToUser(bytes);

    expect(name, startsWith('keycase-'));
    expect(name, endsWith('.kcbak'));
    expect(native.savedName, name);
    expect(native.savedBytes, bytes);
  });

  test('导出取消返回 null，写入异常向上抛出', () async {
    final native = FakeNativeBridge()..saveResult = false;
    final service = BackupService(bridge: native);

    expect(await service.exportToUser(Uint8List(1)), isNull);

    native.saveError = const FileSystemException('write failed');
    await expectLater(
      service.exportToUser(Uint8List(1)),
      throwsA(isA<FileSystemException>()),
    );
  });
}
