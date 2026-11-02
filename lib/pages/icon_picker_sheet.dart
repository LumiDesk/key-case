import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_theme.dart';
import '../app/icons/aegis_icon.dart';
import '../app/icons/aegis_icon_pack.dart';
import '../app/models/models.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 选择条目图标：内置 Aegis 图标（可搜索）或用户自己的图片。
///
/// 自定义图片在选图时就被压到 256px，base64 存进保险库；不做后期裁剪，
/// 避免在渲染路径里做图片处理。
Future<IconRef?> showIconPickerSheet({
  required BuildContext context,
  IconRef? current,
}) {
  return showKcSheet<IconRef>(
    context: context,
    builder: (_) => _IconPickerSheet(current: current),
  );
}

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({this.current});

  final IconRef? current;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  final TextEditingController _query = TextEditingController();
  bool _pickingImage = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _pickCustomImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(
        IconRef(
          kind: IconRef.kindCustom,
          name: 'custom',
          data: base64Encode(bytes),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pack = AegisIconPack.instance;
    final query = _query.text.trim().toLowerCase();
    final names = pack.allNames
        .where((name) {
          if (query.isEmpty) return true;
          return name.toLowerCase().contains(query);
        })
        .take(120)
        .toList();

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.iconPickerTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (widget.current != null)
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const IconRef(name: '')),
                    child: Text(l10n.iconRemove),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.iconSearchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickingImage ? null : _pickCustomImage,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(l10n.iconCustom),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: names.length,
              itemBuilder: (context, index) {
                final name = names[index];
                return InkWell(
                  key: ValueKey<String>('icon_$name'),
                  borderRadius: BorderRadius.circular(kcRadiusMd),
                  onTap: () => Navigator.of(context).pop(IconRef(name: name)),
                  child: Tooltip(
                    message: name,
                    child: Center(child: AegisIcon(name: name, size: 36)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
