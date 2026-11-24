/// 条目图标引用。
///
/// 两种形态共用同一个字段：
/// - `pack`：只存图标标识，体积小、可随包升级；标识里带包前缀
///   （`dashboard:GitHub`），默认包直接用裸名称（`GitHub`）；
/// - `custom`：用户选的自定义图片，PNG 以 base64 存在保险库里（只有用户明确
///   选图时才产生，且导入导出时随容器一起加密）。
library;

import 'dart:convert';
import 'dart:typed_data';

class IconRef {
  const IconRef({
    this.pack = builtinPack,
    required this.name,
    this.kind = kindPack,
    this.data = '',
  });

  /// [pack] 的固定取值；具体图标包由 [name] 的前缀决定，默认包用裸名称。
  static const String builtinPack = 'aegis-simple-icons-v269';
  static const String kindPack = 'pack';
  static const String kindCustom = 'custom';

  final String pack;
  final String name;

  /// `pack` 或 `custom`。
  final String kind;

  /// 自定义图标的 base64 PNG；`pack` 形态为空串。
  final String data;

  bool get isBuiltin => pack.isEmpty || pack == builtinPack;

  bool get isCustom => kind == kindCustom && data.isNotEmpty;

  /// 解码后的图片字节（带 LRU 缓存，避免列表每帧重复解码 base64）。
  Uint8List? get imageBytes {
    if (!isCustom) return null;
    final cached = _decodeCache.remove(data);
    if (cached != null) {
      _decodeCache[data] = cached;
      return cached;
    }
    Uint8List decoded;
    try {
      decoded = base64Decode(data);
    } on FormatException {
      decoded = Uint8List(0);
    }
    _decodeCache[data] = decoded;
    if (_decodeCache.length > _maxDecodeCache) {
      _decodeCache.remove(_decodeCache.keys.first);
    }
    return decoded;
  }

  static const int _maxDecodeCache = 64;
  static final Map<String, Uint8List> _decodeCache = <String, Uint8List>{};

  Map<String, Object?> toJson() => <String, Object?>{
    'pack': pack,
    'name': name,
    'kind': kind,
    if (data.isNotEmpty) 'data': data,
  };

  factory IconRef.fromJson(Map<String, Object?> json) {
    final kind = json['kind'] as String? ?? kindPack;
    return IconRef(
      pack: json['pack'] as String? ?? builtinPack,
      name: json['name'] as String? ?? '',
      kind: kind,
      data: json['data'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IconRef &&
      other.pack == pack &&
      other.name == name &&
      other.kind == kind &&
      other.data == data;

  @override
  int get hashCode => Object.hash(pack, name, kind, data);
}
