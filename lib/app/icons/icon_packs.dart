import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../logging/app_logger.dart';
import '../models/models.dart';

/// 规范化用于匹配的文本：小写并去掉所有非字母数字。
String normalizeIconKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// 内置图标包。顺序即自动匹配的优先级。
///
/// 三套包的画风不同：[simple] 与 [aegis] 是圆形品牌色徽章，[dashboard] 是全彩
/// 服务 logo（渲染时会垫一块浅色底板，深色主题下也看得清黑色字形）。
enum IconPackId { simple, dashboard, aegis }

/// 一套内置包的资源位置。
class IconPackSpec {
  const IconPackSpec({
    required this.id,
    required this.assetRoot,
    required this.attribution,
    required this.licenseFile,
  });

  final IconPackId id;
  final String assetRoot;

  /// 许可证页里显示的来源名称。
  final String attribution;

  /// 包目录下的许可证文件名。
  final String licenseFile;

  String get packAsset => '$assetRoot/pack.json';

  String get licenseAsset => '$assetRoot/$licenseFile';
}

/// 包内一个图标。
@immutable
class IconPackIcon {
  const IconPackIcon({
    required this.pack,
    required this.name,
    required this.path,
  });

  final IconPackId pack;

  /// 展示名，来自图标包或按文件名生成。
  final String name;

  /// SVG 资源路径。
  final String path;

  /// 存进 [IconRef.name] 的标识：默认包用裸名称，其余包加 `包名:` 前缀。
  ///
  /// 裸名称保持旧的存储格式，老条目不需要迁移。
  String get ref => pack == IconPackId.simple ? name : '${pack.name}:$name';

  @override
  bool operator ==(Object other) =>
      other is IconPackIcon && other.pack == pack && other.name == name;

  @override
  int get hashCode => Object.hash(pack, name);
}

/// 内置图标包注册表。
///
/// 三份 `pack.json` 只读一次，在后台 isolate 里解析成「图标列表」与
/// 「issuer → 图标」两张表；之后所有匹配与查找都是内存操作。
/// SVG 文本按图标缓存，列表里同一品牌不会重复读资源。
class IconPacks {
  IconPacks._();

  static final IconPacks instance = IconPacks._();

  /// 资源不足时唯一的事实来源；新增包时只改这里与 pubspec。
  static const List<IconPackSpec> specs = <IconPackSpec>[
    IconPackSpec(
      id: IconPackId.simple,
      assetRoot: 'assets/iconpacks/aegis-simple-icons-v269',
      attribution: 'Simple Icons',
      licenseFile: 'LICENSE.md',
    ),
    IconPackSpec(
      id: IconPackId.dashboard,
      assetRoot: 'assets/iconpacks/dashboard-icons',
      attribution: 'dashboard-icons',
      licenseFile: 'LICENSE.txt',
    ),
    IconPackSpec(
      id: IconPackId.aegis,
      assetRoot: 'assets/iconpacks/aegis-icons',
      attribution: 'aegis-icons',
      licenseFile: 'LICENSE.md',
    ),
  ];

  /// 图标包是否已就绪；页面用 ValueListenableBuilder 监听它做一次重绘。
  final ValueNotifier<bool> loaded = ValueNotifier<bool>(false);

  final List<IconPackIcon> _icons = <IconPackIcon>[];

  /// 存储标识 → 图标。默认包同时登记裸名称与 `simple:` 前缀两种写法。
  final Map<String, IconPackIcon> _byRef = <String, IconPackIcon>{};

  /// 规范化 issuer → [IconPackIcon.ref]，按 [specs] 顺序先到先得。
  final Map<String, String> _refByIssuer = <String, String>{};

  /// 按标题缓存的匹配结果，避免每帧对上千条做包含判断。
  final Map<String, String?> _matchCache = <String, String?>{};

  final Map<String, Future<String?>> _svgFutures = <String, Future<String?>>{};

  Future<void> ensureLoaded() async {
    if (loaded.value) return;
    try {
      final inputs = <({int pack, String root, String raw})>[];
      for (var i = 0; i < specs.length; i++) {
        final spec = specs[i];
        try {
          inputs.add((
            pack: i,
            root: spec.assetRoot,
            raw: await rootBundle.loadString(spec.packAsset),
          ));
        } catch (error) {
          // 单套包缺失不影响其余包：列表回落到剩余图标或首字母头像。
          AppLogger.warn('icon pack ${spec.id.name} missing: $error');
        }
      }
      if (inputs.isEmpty) return;
      // 1.2 MB 级 JSON 在主 isolate 解析会造成可见卡顿；放到后台 isolate。
      final parsed = await Isolate.run(() => _parsePacks(inputs));
      _index(parsed);
      loaded.value = true;
    } catch (error) {
      AppLogger.warn('icon pack load failed: $error');
    }
  }

  void _index(List<_RawIcon> parsed) {
    _icons.clear();
    _byRef.clear();
    _refByIssuer.clear();
    for (final raw in parsed) {
      final spec = specs[raw.pack];
      final icon = IconPackIcon(
        pack: spec.id,
        name: raw.name,
        path: '${spec.assetRoot}/${raw.filename}',
      );
      _icons.add(icon);
      _byRef[icon.ref] = icon;
      if (spec.id == IconPackId.simple) {
        _byRef.putIfAbsent(icon.name, () => icon);
      }
      for (final issuer in raw.issuers) {
        final key = normalizeIconKey(issuer);
        if (key.isEmpty) continue;
        _refByIssuer.putIfAbsent(key, () => icon.ref);
      }
    }
    _icons.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return a.pack.index.compareTo(b.pack.index);
    });
  }

  /// 全部图标，按展示名排序（同名时按包顺序）。
  List<IconPackIcon> get allIcons => List<IconPackIcon>.unmodifiable(_icons);

  /// 某一套包的图标。
  List<IconPackIcon> iconsOf(IconPackId pack) =>
      _icons.where((icon) => icon.pack == pack).toList(growable: false);

  /// 按存储标识或裸名称查找。
  IconPackIcon? find(String ref) {
    final direct = _byRef[ref];
    if (direct != null) return direct;
    final separator = ref.indexOf(':');
    if (separator <= 0) return null;
    final packName = ref.substring(0, separator);
    final name = ref.substring(separator + 1);
    for (final spec in specs) {
      if (spec.id.name == packName) {
        return _byRef['${spec.id.name}:$name'];
      }
    }
    return null;
  }

  /// 为条目挑选图标：显式指定优先，其次按标题、网址主机名匹配。
  ///
  /// 返回值是 [IconPackIcon.ref]；没有命中返回 null。
  String? resolve(VaultItem item) {
    final explicit = item.icon;
    if (explicit != null && !explicit.isCustom && explicit.name.isNotEmpty) {
      // 空名字表示用户主动选择「恢复自动匹配」，继续往下走。
      final hit = find(explicit.name);
      if (hit != null) return hit.ref;
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
    var result = _refByIssuer[key];
    if (result == null) {
      // 标题里可能带后缀（GitHub Enterprise）或前缀（AWS Console）：
      // 先按整串包含匹配最长 issuer，再逐词试一次。
      var bestLength = 0;
      for (final entry in _refByIssuer.entries) {
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
          final hit = _refByIssuer[wordKey];
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

  /// 读取 SVG 文本（按图标缓存 Future）。
  Future<String?> svgFor(String ref) {
    return _svgFutures.putIfAbsent(ref, () async {
      final icon = find(ref);
      if (icon == null) return null;
      try {
        return await rootBundle.loadString(icon.path);
      } catch (error) {
        AppLogger.warn('icon svg load failed ($ref): $error');
        return null;
      }
    });
  }

  /// 搜索：按名称、issuer 命中；空查询返回全部。
  List<IconPackIcon> search(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return allIcons;
    final key = normalizeIconKey(trimmed);
    final hits = _icons.where((icon) {
      if (icon.name.toLowerCase().contains(trimmed)) return true;
      if (key.isEmpty) return false;
      final resolved = _refByIssuer[key];
      if (resolved == icon.ref) return true;
      return normalizeIconKey(icon.name).contains(key);
    });
    return hits.toList(growable: false);
  }
}

typedef _RawIcon = ({
  int pack,
  String name,
  String filename,
  List<String> issuers,
});

/// 在后台 isolate 里解析三份 pack.json。
List<_RawIcon> _parsePacks(List<({int pack, String root, String raw})> inputs) {
  final icons = <_RawIcon>[];
  for (final input in inputs) {
    final decoded = jsonDecode(input.raw);
    if (decoded is! Map<String, dynamic>) continue;
    final entries = (decoded['icons'] as List?) ?? const <dynamic>[];
    for (final entry in entries) {
      if (entry is! Map) continue;
      final name = entry['name'] as String? ?? '';
      final filename = entry['filename'] as String? ?? '';
      if (name.isEmpty || filename.isEmpty) continue;
      final rawIssuers = (entry['issuer'] as List?) ?? const <dynamic>[];
      icons.add((
        pack: input.pack,
        name: name,
        filename: filename,
        issuers: <String>[for (final issuer in rawIssuers) '$issuer'],
      ));
    }
  }
  return icons;
}
