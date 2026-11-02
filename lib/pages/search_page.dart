import 'package:flutter/material.dart';

import '../app/keycase_scope.dart';
import '../app/models/models.dart';
import '../app/otp/otp_clock.dart';
import '../app/vault/vault_query.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'detail_page.dart';
import 'item_tiles.dart';

/// 全局搜索：同时返回登录项与令牌。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final preferences = controller.preferences;
    final l10n = AppLocalizations.of(context);
    final results = searchItems(controller.state.activeItems, _query.text);
    final logins = results.where((item) => !item.isToken).toList();
    final tokens = results.where((item) => item.isToken).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: KcPage(
          child: Column(
            children: <Widget>[
              KcSubHeader(
                title: l10n.searchTitle,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: TextField(
                  controller: _query,
                  focusNode: _focus,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
              Expanded(
                child: _query.text.trim().isEmpty
                    ? const SizedBox.shrink()
                    : results.isEmpty
                    ? KcEmptyState(
                        icon: Icons.search_off_rounded,
                        title: l10n.searchNoResults,
                        description: l10n.searchNoResultsDesc,
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 32),
                        children: <Widget>[
                          if (logins.isNotEmpty) ...<Widget>[
                            KcSectionLabel(l10n.navLogins),
                            _ResultCard(
                              items: logins,
                              preferences: preferences,
                              clock: controller.clock,
                            ),
                          ],
                          if (tokens.isNotEmpty) ...<Widget>[
                            KcSectionLabel(l10n.navTokens),
                            _ResultCard(
                              items: tokens,
                              preferences: preferences,
                              clock: controller.clock,
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.items,
    required this.preferences,
    required this.clock,
  });

  final List<VaultItem> items;
  final AppPreferences preferences;
  final OtpClock clock;

  @override
  Widget build(BuildContext context) {
    return KcCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < items.length; i++) ...<Widget>[
            if (items[i].isToken)
              KcTokenTile(
                key: ValueKey<String>(items[i].id),
                item: items[i],
                clock: clock,
                showCode: preferences.showTokenCodes,
                showNext: preferences.showNextToken,
                grouping: preferences.codeGrouping,
                onTap: () => _open(context, items[i]),
              )
            else
              KcLoginTile(
                key: ValueKey<String>(items[i].id),
                item: items[i],
                onTap: () => _open(context, items[i]),
              ),
            if (i != items.length - 1) const KcRowDivider(),
          ],
        ],
      ),
    );
  }

  void _open(BuildContext context, VaultItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ItemDetailPage(itemId: item.id)),
    );
  }
}
