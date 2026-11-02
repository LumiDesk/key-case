import 'models/models.dart';
import 'keycase_controller.dart';
import 'keycase_state.dart';

/// 仅本地调试用的演示数据开关。
///
/// 通过 `--dart-define=SEED_DEMO=true` 打开：首次启动自动建库并写入示例条目，
/// 之后每次启动自动解锁，方便在模拟器上直接截图与点按验收。
/// 正式构建不带这个 define，代码路径不会执行。
const bool kSeedDemo = bool.fromEnvironment('SEED_DEMO');

const String demoMasterPassword = 'demo-password';

Future<void> prepareDemoIfNeeded(KeyCaseController controller) async {
  if (!kSeedDemo) return;
  if (controller.state.status == VaultStatus.missing) {
    await controller.createVault(
      password: demoMasterPassword,
      confirm: demoMasterPassword,
    );
  } else if (controller.state.status == VaultStatus.locked) {
    await controller.unlock(demoMasterPassword);
  }
  if (!controller.state.isUnlocked) return;
  if (controller.state.activeItems.isNotEmpty) return;
  await _seedItems(controller);
}

Future<void> _seedItems(KeyCaseController controller) async {
  final now = DateTime.now().toUtc();
  final items = <VaultItem>[
    VaultItem(
      id: 'demo-github',
      kind: ItemKind.login,
      title: 'GitHub',
      username: 'talyra42',
      password: 'Tr0ub4dor&3-correct-horse',
      urls: const <String>['https://github.com'],
      notes: '主账号，开启了两步验证',
      favorite: true,
      createdAt: now.subtract(const Duration(days: 120)),
      updatedAt: now.subtract(const Duration(days: 20)),
    ),
    VaultItem(
      id: 'demo-google',
      kind: ItemKind.login,
      title: 'Google',
      username: 'talyra42@gmail.com',
      password: 'password123',
      urls: const <String>['https://accounts.google.com'],
      createdAt: now.subtract(const Duration(days: 400)),
      updatedAt: now.subtract(const Duration(days: 400)),
    ),
    VaultItem(
      id: 'demo-bank',
      kind: ItemKind.login,
      title: '招商银行',
      username: '6225 **** **** 1234',
      password: 'password123',
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now.subtract(const Duration(days: 30)),
    ),
    VaultItem(
      id: 'demo-aws',
      kind: ItemKind.login,
      title: 'AWS Console',
      username: 'ops@example.com',
      password: 'G8#vQ2!mR7@xL4',
      urls: const <String>['https://console.aws.amazon.com'],
      createdAt: now.subtract(const Duration(days: 60)),
      updatedAt: now.subtract(const Duration(days: 5)),
    ),
    VaultItem(
      id: 'demo-totp-github',
      kind: ItemKind.totp,
      title: 'GitHub',
      username: 'talyra42',
      totp: const TotpSecret(secret: 'JBSWY3DPEHPK3PXP'),
      favorite: true,
      createdAt: now.subtract(const Duration(days: 90)),
      updatedAt: now.subtract(const Duration(days: 3)),
    ),
    VaultItem(
      id: 'demo-totp-cloudflare',
      kind: ItemKind.totp,
      title: 'Cloudflare',
      username: 'ops@example.com',
      totp: const TotpSecret(
        secret: 'KRSXG5CTMVRXEZLUKN2XAZLSKNSWG4TFOQ',
        digits: 6,
        period: 30,
      ),
      createdAt: now.subtract(const Duration(days: 45)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    VaultItem(
      id: 'demo-hotp',
      kind: ItemKind.totp,
      title: 'Legacy HOTP',
      username: 'example',
      totp: const TotpSecret(
        type: OtpType.hotp,
        secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
        counter: 4,
      ),
      createdAt: now.subtract(const Duration(days: 200)),
      updatedAt: now.subtract(const Duration(days: 200)),
    ),
    VaultItem(
      id: 'demo-steam',
      kind: ItemKind.totp,
      title: 'Steam',
      username: 'talyra42',
      totp: const TotpSecret(
        type: OtpType.steam,
        secret: 'MZXW6YTBOI======',
        digits: 5,
      ),
      createdAt: now.subtract(const Duration(days: 15)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    VaultItem(
      id: 'demo-trashed',
      kind: ItemKind.login,
      title: '旧测试账号',
      username: 'old@example.com',
      password: 'OldPassword1',
      createdAt: now.subtract(const Duration(days: 300)),
      updatedAt: now.subtract(const Duration(days: 10)),
      deletedAt: now.subtract(const Duration(days: 2)),
    ),
  ];
  for (final item in items) {
    await controller.saveItem(item);
  }
}
