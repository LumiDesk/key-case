import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'aegis_icon_pack.dart';

/// 单个品牌图标。
///
/// 直接渲染 SVG：Aegis 包里的图标自带配色，不做 tint。
/// `flutter_svg` 会按 SVG 文本缓存解析结果，列表滚动时不会重复解析。
class AegisIcon extends StatelessWidget {
  const AegisIcon({super.key, required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AegisIconPack.instance.svgFor(name),
      builder: (context, snapshot) {
        final svg = snapshot.data;
        if (svg == null) {
          return SizedBox(width: size, height: size);
        }
        return SizedBox(
          width: size,
          height: size,
          child: SvgPicture.string(svg, width: size, height: size),
        );
      },
    );
  }
}
