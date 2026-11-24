import 'package:anchored_menu/anchored_menu.dart';
import 'package:flutter/material.dart';

import '../app/icons/brand_icon.dart';
import '../app/icons/icon_pack_labels.dart';
import '../app/icons/icon_packs.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 只读图标库：浏览全部内置图标，可搜索、按包筛选、点开看大图。
///
/// 图标随 APK 打包，这里只做预览：不提供导入，也不改写任何图标。
class IconLibraryPage extends StatefulWidget {
  const IconLibraryPage({super.key});

  @override
  State<IconLibraryPage> createState() => _IconLibraryPageState();
}

class _IconLibraryPageState extends State<IconLibraryPage> {
  final TextEditingController _query = TextEditingController();

  /// null 表示不筛选。
  IconPackId? _pack;

  @override
  void initState() {
    super.initState();
    IconPacks.instance.loaded.addListener(_onPackLoaded);
  }

  void _onPackLoaded() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    IconPacks.instance.loaded.removeListener(_onPackLoaded);
    _query.dispose();
    super.dispose();
  }

  List<IconPackIcon> get _icons {
    final matches = IconPacks.instance.search(_query.text);
    final pack = _pack;
    if (pack == null) return matches;
    return matches.where((icon) => icon.pack == pack).toList(growable: false);
  }

  Future<void> _preview(IconPackIcon icon) {
    final l10n = AppLocalizations.of(context);
    return showKcSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              KcBrandIcon(ref: icon.ref, size: 72),
              const SizedBox(height: 14),
              Text(
                icon.name,
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                packLabel(l10n, icon.pack),
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurface
                      .withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final icons = _icons;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: KcPage(
          child: Column(
            children: <Widget>[
              KcSubHeader(
                title: l10n.iconLibraryTitle,
                onBack: () => Navigator.of(context).maybePop(),
                actions: <Widget>[
                  AnchoredMenuButton(
                    icon: Icons.filter_list_rounded,
                    tooltip: l10n.iconLibraryFilter,
                    entries: <AnchoredMenuEntry>[
                      _filterEntry(l10n.iconLibraryAll, null),
                      for (final spec in IconPacks.specs)
                        _filterEntry(packLabel(l10n, spec.id), spec.id),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.iconSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.actionCancel,
                            onPressed: () {
                              _query.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.iconLibraryCount(icons.length),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: !IconPacks.instance.loaded.value
                    ? const Center(child: CircularProgressIndicator())
                    : icons.isEmpty
                    ? KcEmptyState(
                        icon: Icons.search_off_rounded,
                        title: l10n.searchNoResults,
                        description: l10n.searchNoResultsDesc,
                      )
                    : KcIconGrid(
                        icons: icons,
                        keyPrefix: 'icon_library',
                        onIconTap: _preview,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AnchoredMenuEntry _filterEntry(String label, IconPackId? pack) {
    return AnchoredMenuItem(
      id: pack?.name ?? 'all',
      title: label,
      selected: _pack == pack,
      onPressed: () => setState(() => _pack = pack),
    );
  }
}
