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
}
