import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../logging/app_logger.dart';
import '../models/models.dart';

/// 规范化用于匹配的文本：小写并去掉所有非字母数字。
String normalizeIconKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// 内置 Aegis Simple Icons 图标包。
///
/// 包只读一次：`pack.json` 有 3400+ 条，解析成「issuer → 图标名」与
/// 「图标名 → SVG 路径」两张表，之后所有匹配都是内存操作。
/// SVG 文本按需加载并按图标名缓存，列表里同一品牌不会重复读资源。
class AegisIconPack {
  AegisIconPack._();

  static final AegisIconPack instance = AegisIconPack._();

  static const String assetRoot = 'assets/iconpacks/aegis-simple-icons-v269';
  static const String packAsset = '$assetRoot/pack.json';

  /// 图标包是否已就绪；列表用 ValueListenableBuilder 监听它做一次重绘。
  final ValueNotifier<bool> loaded = ValueNotifier<bool>(false);

  /// 图标名 → 资源相对路径。
  final Map<String, String> _fileByName = <String, String>{};

  /// 规范化 issuer → 图标名。
  final Map<String, String> _nameByIssuer = <String, String>{};

  /// 按标题缓存的匹配结果，避免每帧对 3400 条做包含判断。
  final Map<String, String?> _matchCache = <String, String?>{};

  final Map<String, Future<String?>> _svgFutures = <String, Future<String?>>{};

  Future<void> ensureLoaded() async {
    if (loaded.value) return;
    try {
      final raw = await rootBundle.loadString(packAsset);
      // 667 KB JSON 在主 isolate 解析会造成可见卡顿；放到后台 isolate。
      final parsed = await Isolate.run(() => _parsePack(raw));
      _fileByName.addAll(parsed.files);
      _nameByIssuer.addAll(parsed.issuers);
      loaded.value = true;
    } catch (error) {
      // 图标包缺失不影响主流程：所有条目回落到首字母头像。
      AppLogger.warn('icon pack load failed: $error');
    }
  }

  /// 为条目挑选图标名：显式指定优先，其次按标题、网址主机名匹配。
  String? resolve(VaultItem item) {
    final explicit = item.icon;
    if (explicit != null && !explicit.isCustom) {
      // 空名字表示用户主动选择「恢复自动匹配」，继续往下走。
      if (explicit.name.isNotEmpty) {
        return _fileByName.containsKey(explicit.name) ? explicit.name : null;
      }
    }
    if (!loaded.value) return null;
    final title = item.title.trim();
    if (title.isNotEmpty) {
      final byTitle = _match(title);
      if (byTitle != null) return byTitle;
    }
    for (final url in item.urls) {
      final host = Uri.tryParse(url.contains('://') ? url : 'https://$url')
          ?.host;
      if (host == null || host.isEmpty) continue;
      final parts = host.split('.');
      if (parts.length >= 2) {
        final byHost = _match(parts[parts.length - 2]);
        if (byHost != null) return byHost;
      }
    }
    return null;
  }

  String? _match(String text) {
    final cached = _matchCache.remove(text);
    if (cached != null) {
      _matchCache[text] = cached;
      return cached;
    }
    final key = normalizeIconKey(text);
    if (key.isEmpty) return null;
    var result = _nameByIssuer[key];
    if (result == null) {
      // 标题里可能带后缀（GitHub Enterprise）或前缀（AWS Console）：
      // 先按整串包含匹配最长 issuer，再逐词试一次。
      var bestLength = 0;
      for (final entry in _nameByIssuer.entries) {
        if (entry.key.length < 3 || entry.key.length <= bestLength) continue;
        if (key.contains(entry.key)) {
          result = entry.value;
          bestLength = entry.key.length;
        }
      }
      if (result == null) {
        for (final word in text.split(RegExp(r'[^A-Za-z0-9]+'))) {
          final wordKey = normalizeIconKey(word);
          if (wordKey.length < 3) continue;
          final hit = _nameByIssuer[wordKey];
          if (hit != null) {
            result = hit;
            break;
          }
        }
      }
    }
    if (result != null) _storeMatch(text, result);
    return result;
  }

  void _storeMatch(String text, String value) {
    _matchCache[text] = value;
    if (_matchCache.length > _maxMatchCache) {
      _matchCache.remove(_matchCache.keys.first);
    }
  }

  static const int _maxMatchCache = 256;

  /// 读取 SVG 文本（按图标名缓存 Future）。
  Future<String?> svgFor(String name) {
    return _svgFutures.putIfAbsent(name, () async {
      final filename = _fileByName[name];
      if (filename == null) return null;
      try {
        return await rootBundle.loadString('$assetRoot/$filename');
      } catch (error) {
        AppLogger.warn('icon svg load failed ($name): $error');
        return null;
      }
    });
  }

  /// 供图标选择器使用的全部图标名（已排序）。
  List<String> get allNames => _fileByName.keys.toList()..sort();
}

({Map<String, String> files, Map<String, String> issuers}) _parsePack(
  String raw,
) {
  final files = <String, String>{};
  final issuersByName = <String, String>{};
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    return (files: files, issuers: issuersByName);
  }
  final icons = (decoded['icons'] as List?) ?? const <dynamic>[];
  for (final entry in icons) {
    if (entry is! Map) continue;
    final name = entry['name'] as String? ?? '';
    final filename = entry['filename'] as String? ?? '';
    if (name.isEmpty || filename.isEmpty) continue;
    files[name] = filename;
    final issuers = (entry['issuer'] as List?) ?? const <dynamic>[];
    for (final issuer in issuers) {
      final key = normalizeIconKey('$issuer');
      if (key.isNotEmpty) {
        issuersByName.putIfAbsent(key, () => name);
      }
    }
  }
  return (files: files, issuers: issuersByName);
}
