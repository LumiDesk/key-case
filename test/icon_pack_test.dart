import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/icons/icon_packs.dart';
import 'package:keycase/app/models/models.dart';

VaultItem _login({String title = 'GitHub', IconRef? icon}) =>
    VaultItem.loginItem(
      id: 'item',
      title: title,
      icon: icon,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await IconPacks.instance.ensureLoaded();
  });

  test('三套内置图标包全部加载', () {
    final packs = IconPacks.instance;
    expect(packs.loaded.value, isTrue);
    expect(IconPacks.specs, hasLength(3));
    for (final spec in IconPacks.specs) {
      expect(
        packs.iconsOf(spec.id),
        isNotEmpty,
        reason: '${spec.id.name} 应该至少有一个图标',
      );
    }
    expect(packs.allIcons.length, greaterThan(6000));
  });

  test('每个图标都有名称、资源路径与可用 SVG', () async {
    final packs = IconPacks.instance;
    for (final name in <String>['GitHub', 'Plex', 'Proxmox']) {
      final icons = packs.allIcons.where((icon) => icon.name == name);
      expect(icons, isNotEmpty, reason: '$name 应该有图标');
    }

    // 抽样每套包各一个图标，确认资源真的读得出来。
    for (final spec in IconPacks.specs) {
      final icon = packs.iconsOf(spec.id).first;
      final svg = await packs.svgFor(icon.ref);
      expect(svg, isNotNull, reason: '${icon.ref} 应该能读到 SVG');
      expect(svg, contains('<svg'));
    }
  });

  test('标题与网址都能自动匹配到图标', () {
    final packs = IconPacks.instance;
    final byTitle = packs.resolve(_login());
    expect(byTitle, isNotNull);
    expect(packs.find(byTitle!), isNotNull);

    final byUrl = packs.resolve(
      VaultItem.loginItem(
        id: 'url',
        title: '我的网盘',
        login: const LoginData(urls: <String>['https://nextcloud.example.com']),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    expect(byUrl, isNotNull);
  });

  test('显式图标优先于标题匹配，并支持包前缀', () {
    final packs = IconPacks.instance;
    final explicit = packs.iconsOf(IconPackId.simple).first;
    expect(
      packs.resolve(_login(icon: IconRef(name: explicit.name))),
      explicit.name,
    );

    final colored = packs.iconsOf(IconPackId.dashboard).first;
    final resolved = packs.resolve(_login(icon: IconRef(name: colored.ref)));
    expect(resolved, colored.ref);
    expect(resolved, contains(':'));
  });

  test('空名称表示恢复自动匹配', () {
    final packs = IconPacks.instance;
    final resolved = packs.resolve(_login(icon: const IconRef(name: '')));
    expect(resolved, isNotNull);
    expect(packs.find(resolved!)?.pack, isNotNull);
  });

  test('搜索命中名称与别名', () {
    final packs = IconPacks.instance;
    expect(packs.search('github').map((icon) => icon.name), contains('GitHub'));
    expect(packs.search('').length, packs.allIcons.length);
    expect(packs.search('zzzz-not-a-brand'), isEmpty);
  });
}
