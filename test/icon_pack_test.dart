import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/icons/aegis_icon_pack.dart';
import 'package:keycase/app/models/models.dart';

void main() {
  test('图标包加载完整目录并匹配品牌', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pack = AegisIconPack.instance;
    await pack.ensureLoaded();

    expect(pack.loaded.value, isTrue);
    expect(pack.allNames.length, greaterThan(1000));

    final item = VaultItem(
      id: 'github',
      kind: ItemKind.login,
      title: 'GitHub',
      urls: const <String>['https://github.com'],
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final icon = pack.resolve(item);
    expect(icon, isNotNull);
    expect(await pack.svgFor(icon!), isNotNull);
  });

  test('显式图标优先于标题匹配', () async {
    final pack = AegisIconPack.instance;
    await pack.ensureLoaded();
    final explicit = pack.allNames.first;
    final name = pack.resolve(
      VaultItem(
        id: 'explicit',
        kind: ItemKind.login,
        title: 'GitHub',
        icon: IconRef(name: explicit),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    expect(name, explicit);
  });
}
