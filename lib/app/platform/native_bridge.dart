import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/app_logger.dart';

/// 原生能力桥。整个应用只用一个 MethodChannel，按方法名分发。
///
/// 目前只有两件事必须走原生：
/// - `FLAG_SECURE`（防止截屏/录屏）；
/// - Android Keystore 包裹的 vault key（生物识别解锁）。
///
/// 其余能力都有官方插件。非 Android 平台（单元测试、桌面调试）全部降级为
/// 无操作，调用方不需要判平台。
class NativeBridge {
  NativeBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'top.talyra42.keycase/native';

  final MethodChannel _channel;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  Future<void> setSecureScreen(bool enabled) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('setSecureScreen', enabled);
    } on PlatformException catch (error) {
      // 截屏保护失败不阻断使用，但必须留下线索。
      AppLogger.warn('setSecureScreen failed: ${error.message}');
    } on MissingPluginException {
      AppLogger.warn('setSecureScreen: native channel missing');
    }
  }

  /// 用 Keystore 密钥加密 vault key 并落盘。失败返回 false。
  Future<bool> storeVaultKey({
    required Uint8List key,
    required String vaultId,
  }) async {
    if (!_supported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('storeVaultKey', {
        'key': key,
        'vaultId': vaultId,
      });
      return result ?? false;
    } on PlatformException catch (error) {
      AppLogger.warn('storeVaultKey failed: ${error.message}');
      return false;
    } on MissingPluginException {
      AppLogger.warn('storeVaultKey: native channel missing');
      return false;
    }
  }

  /// 读回并解密 vault key；没有登记或解密失败返回 null。
  Future<Uint8List?> readVaultKey(String vaultId) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('readVaultKey', {
        'vaultId': vaultId,
      });
    } on PlatformException catch (error) {
      AppLogger.warn('readVaultKey failed: ${error.message}');
      return null;
    } on MissingPluginException {
      AppLogger.warn('readVaultKey: native channel missing');
      return null;
    }
  }

  Future<void> clearVaultKey() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('clearVaultKey');
    } on PlatformException catch (error) {
      AppLogger.warn('clearVaultKey failed: ${error.message}');
    } on MissingPluginException {
      AppLogger.warn('clearVaultKey: native channel missing');
    }
  }

  /// 让用户选一个备份目录（SAF）；取消返回 null。
  Future<({String uri, String name})?> pickBackupFolder() async {
    if (!_supported) return null;
    try {
      final result = await _channel.invokeMapMethod<String, String>(
        'pickBackupFolder',
      );
      if (result == null) return null;
      final uri = result['uri'];
      final name = result['name'];
      if (uri == null || uri.isEmpty) return null;
      return (uri: uri, name: name ?? '备份目录');
    } on PlatformException catch (error) {
      AppLogger.warn('pickBackupFolder failed: ${error.message}');
      return null;
    } on MissingPluginException {
      AppLogger.warn('pickBackupFolder: native channel missing');
      return null;
    }
  }

  /// 把加密快照写进所选的 SAF 目录（应用会在其中创建 KeyCase 子目录）。
  Future<bool> writeBackupFile({
    required String dirUri,
    required String name,
    required Uint8List bytes,
  }) async {
    if (!_supported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('writeBackupFile', {
        'dirUri': dirUri,
        'name': name,
        'bytes': bytes,
      });
      return ok ?? false;
    } on PlatformException catch (error) {
      AppLogger.warn('writeBackupFile failed: ${error.message}');
      return false;
    } on MissingPluginException {
      AppLogger.warn('writeBackupFile: native channel missing');
      return false;
    }
  }

  /// 列出目录里的快照文件名（按名字降序，即时间从新到旧）。
  Future<List<String>> listBackupFiles(String dirUri) async {
    if (!_supported) return const <String>[];
    try {
      final files = await _channel.invokeListMethod<String>('listBackupFiles', {
        'dirUri': dirUri,
      });
      return files ?? const <String>[];
    } on PlatformException catch (error) {
      AppLogger.warn('listBackupFiles failed: ${error.message}');
      return const <String>[];
    } on MissingPluginException {
      return const <String>[];
    }
  }

  Future<bool> deleteBackupFiles({
    required String dirUri,
    required List<String> names,
  }) async {
    if (!_supported || names.isEmpty) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('deleteBackupFiles', {
        'dirUri': dirUri,
        'names': names,
      });
      return ok ?? false;
    } on PlatformException catch (error) {
      AppLogger.warn('deleteBackupFiles failed: ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
