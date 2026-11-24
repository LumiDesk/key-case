import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_theme.dart';
import 'icon_packs.dart';

/// 单个品牌图标。
///
/// 直接渲染 SVG：图标自带配色，不做 tint。`flutter_svg` 会按 SVG 文本缓存
/// 解析结果，列表滚动时不会重复解析。
///
/// 全彩包（[IconPackId.dashboard]）里有相当一部分是纯黑字形，直接铺在深色卡片
/// 上会看不见，因此这类图标额外垫一块浅色圆角底板。
class KcBrandIcon extends StatelessWidget {
  const KcBrandIcon({super.key, required this.ref, required this.size});

  /// [IconPackIcon.ref]（默认包是裸名称）。
  final String ref;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = IconPacks.instance.find(ref);
    final svg = FutureBuilder<String?>(
      future: IconPacks.instance.svgFor(ref),
      builder: (context, snapshot) {
        final text = snapshot.data;
        if (text == null) {
          return SizedBox(width: size, height: size);
        }
        return SizedBox(
          width: size,
          height: size,
          child: SvgPicture.string(text, width: size, height: size),
        );
      },
    );
    if (icon?.pack != IconPackId.dashboard) return svg;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      decoration: BoxDecoration(
        color: kcIconPlate,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: svg,
    );
  }
}
