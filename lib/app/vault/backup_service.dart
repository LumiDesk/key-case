import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 备份仓库：自动快照 + 手动导出/导入。
///
/// 自动快照放在应用私有目录，只保留最近 [keepSnapshots] 份；用户主动导出才走
/// 系统文档选择器。两种形态都是同一个加密容器，扩展名 `.kcbak`。
class BackupService {
  BackupService({Directory? directory}) : _directoryOverride = directory;

  static const int keepSnapshots = 10;
  static const int maxImportBytes = 64 * 1024 * 1024;
  static const String fileExtension = 'kcbak';

  final Directory? _directoryOverride;

  Future<Directory> _backupDirectory() async {
    final base = _directoryOverride ?? await getApplicationSupportDirectory();
    final directory = Directory(p.join(base.path, 'backups'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// 写入一份自动快照并清理旧文件；返回快照路径。
  Future<String> snapshot(Uint8List bytes) async {
    final directory = await _backupDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final file = File(p.join(directory.path, 'keycase-$stamp.$fileExtension'));
    await file.writeAsBytes(bytes, flush: true);
    await _prune(directory);
    return file.path;
  }

  Future<List<File>> listSnapshots() async {
    final directory = await _backupDirectory();
    final files = await directory
        .list()
        .where(
          (entity) => entity is File && entity.path.endsWith('.$fileExtension'),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> _prune(Directory directory) async {
    final snapshots = await listSnapshots();
    for (var i = keepSnapshots; i < snapshots.length; i++) {
      await snapshots[i].delete();
    }
  }

  /// 让用户选一个位置导出当前库；取消返回 null。
  Future<String?> exportToUser(Uint8List bytes) async {
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final location = await getSaveLocation(
      suggestedName: 'keycase-$stamp.$fileExtension',
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'KeyCase 加密备份', extensions: <String>[fileExtension]),
      ],
    );
    if (location == null) return null;
    final file = File(location.path);
    await file.writeAsBytes(bytes, flush: true);
    return location.path;
  }

  /// 让用户挑一个备份文件并读入内存；取消返回 null。
  Future<Uint8List?> pickImportFile() => pickDocument(
    label: 'KeyCase 加密备份',
    extensions: const <String>[fileExtension, 'kcv', 'bin'],
  );

  /// 通用文档选择：读入内存（上限 64 MB），取消返回 null。
  ///
  /// 只用于几十 MB 以内的配置文件；大文件走原生流式接口，不要用这里。
  Future<Uint8List?> pickDocument({
    required String label,
    required List<String> extensions,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(label: label, extensions: extensions),
      ],
    );
    if (file == null) return null;
    final length = await file.length();
    if (length > maxImportBytes) {
      throw const FormatException('备份文件过大（超过 64 MB）');
    }
    return file.readAsBytes();
  }
}
