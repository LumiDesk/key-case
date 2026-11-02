import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';

import '../platform/native_bridge.dart';

/// 备份：手动导出/导入 + 写进用户选定目录的自动快照。
///
/// 快照只写用户明确选过的 SAF 目录（其下的 KeyCase 子目录），保留最近
/// [keepSnapshots] 份；没有选目录时不做任何自动写入。
class BackupService {
  BackupService({NativeBridge? bridge}) : _bridge = bridge ?? NativeBridge();

  static const int keepSnapshots = 10;
  static const String fileExtension = 'kcbak';
  static const int maxImportBytes = 64 * 1024 * 1024;

  final NativeBridge _bridge;

  /// 让用户选备份目录；取消返回 null。
  Future<({String uri, String name})?> pickFolder() =>
      _bridge.pickBackupFolder();

  /// 写入一份加密快照并清理超出的旧份数；返回文件名。
  Future<String> writeSnapshot({
    required String dirUri,
    required Uint8List bytes,
  }) async {
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final name = 'keycase-$stamp.$fileExtension';
    final ok = await _bridge.writeBackupFile(
      dirUri: dirUri,
      name: name,
      bytes: bytes,
    );
    if (!ok) {
      throw const FileSystemException('无法写入备份目录');
    }
    final files = await _bridge.listBackupFiles(dirUri);
    if (files.length > keepSnapshots) {
      await _bridge.deleteBackupFiles(
        dirUri: dirUri,
        names: files.sublist(keepSnapshots),
      );
    }
    return name;
  }

  Future<List<String>> listSnapshots(String dirUri) =>
      _bridge.listBackupFiles(dirUri);

  /// 让用户选一个位置导出当前库；取消返回 null。
  Future<String?> exportToUser(Uint8List bytes) async {
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final name = 'keycase-$stamp.$fileExtension';
    final saved = await _bridge.saveBackupFile(name: name, bytes: bytes);
    return saved ? name : null;
  }

  /// 让用户挑一个备份文件并读入内存；取消返回 null。
  Future<Uint8List?> pickImportFile() => pickDocument(
    label: 'KeyCase 加密备份',
    extensions: const <String>[fileExtension, 'kcv', 'bin'],
  );

  /// 通用文档选择：读入内存（上限 64 MB），取消返回 null。
  ///
  /// 只用于几十 MB 以内的配置文件；更大的文件不要走这里。
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
