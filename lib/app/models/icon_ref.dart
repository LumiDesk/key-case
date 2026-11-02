/// 条目图标引用。
///
/// 图标只引用「包 + 图标名」，不把 SVG 或位图存进保险库：体积小、可随包升级，
/// 且导出/导入不需要额外处理二进制。
library;

class IconRef {
  const IconRef({this.pack = builtinPack, required this.name});

  /// 内置 Aegis Simple Icons 包。空字符串同样表示内置包。
  static const String builtinPack = 'aegis-simple-icons-v269';

  final String pack;
  final String name;

  bool get isBuiltin => pack.isEmpty || pack == builtinPack;

  Map<String, Object?> toJson() => <String, Object?>{
    'pack': pack,
    'name': name,
  };

  factory IconRef.fromJson(Map<String, Object?> json) {
    final pack = json['pack'] as String? ?? builtinPack;
    return IconRef(pack: pack, name: json['name'] as String? ?? '');
  }

  @override
  bool operator ==(Object other) =>
      other is IconRef && other.pack == pack && other.name == name;

  @override
  int get hashCode => Object.hash(pack, name);
}
