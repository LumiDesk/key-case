import '../crypto/base32.dart';
import '../crypto/random.dart';
import '../models/models.dart';

/// bridge 构建专用的 v1 读取与迁移。
///
/// 最终纯 v2 代码会删除本文件与所有引用；不要把它带进 final。
class VaultMigrationReport {
  const VaultMigrationReport({
    required this.total,
    required this.migrated,
    required this.skipped,
    required this.repaired,
    required this.warnings,
  });

  final int total;
  final int migrated;
  final int skipped;
  final int repaired;

  /// 只放错误码/类别，不放标题、账号、secret、密码。
  final List<String> warnings;

  bool get hasIssues => skipped > 0 || repaired > 0;
}

class VaultDecoded {
  const VaultDecoded({required this.data, this.migration});

  final VaultData data;
  final VaultMigrationReport? migration;
}

/// v1 payload（胖对象）→ v2 payload（login/totp 互斥）。
VaultDecoded migrateV1Vault(Map<String, Object?> json, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final vaultId = json['vaultId'] as String? ?? '';
  final createdAt = _parseDate(json['createdAt']) ?? reference;
  final rawItems = json['items'];

  var repaired = 0;
  var skipped = 0;
  final warnings = <String>[];
  final ids = <String>{};
  final items = <VaultItem>[];

  if (rawItems is List) {
    for (final raw in rawItems) {
      if (raw is! Map) {
        skipped++;
        warnings.add('item-not-map');
        continue;
      }
      final entry = raw.cast<String, Object?>();
      var itemRepaired = false;

      var id = entry['id'] as String? ?? '';
      if (id.isEmpty || ids.contains(id)) {
        id = newId();
        ids.add(id);
        itemRepaired = true;
        warnings.add('item-id-regenerated');
      } else {
        ids.add(id);
      }

      final title = entry['title'] as String? ?? '';
      final favoriteRaw = entry['favorite'];
      final favorite = favoriteRaw is bool ? favoriteRaw : false;
      if (favoriteRaw != null && favoriteRaw is! bool) itemRepaired = true;
      final icon = _migrateIcon(entry['icon'], () => itemRepaired = true);
      final itemCreatedAt =
          _parseDate(entry['createdAt']) ??
          _fallbackDate(
            entry['createdAt'],
            reference,
            () => itemRepaired = true,
          );
      final itemUpdatedAt =
          _parseDate(entry['updatedAt']) ??
          _fallbackDate(
            entry['updatedAt'],
            reference,
            () => itemRepaired = true,
          );
      final deletedAt = _migrateDeletedAt(
        entry['deletedAt'],
        () => itemRepaired = true,
      );

      if (entry['kind'] == 'totp') {
        final rawTotp = entry['totp'];
        if (rawTotp is! Map) {
          skipped++;
          warnings.add('token-missing-payload');
          continue;
        }
        final totp = rawTotp.cast<String, Object?>();
        final type = _otpType(totp['type']);
        final secret = normalizeBase32('${totp['secret'] ?? ''}');
        if (secret.isEmpty || !_validBase32(secret)) {
          skipped++;
          warnings.add('token-invalid-secret');
          continue;
        }
        final rawDigits = (totp['digits'] as num?)?.toInt();
        final rawPeriod = (totp['period'] as num?)?.toInt();
        final rawCounter = (totp['counter'] as num?)?.toInt() ?? 0;
        final algorithm = _algorithm(totp['algorithm']);

        if (entry['password'] is String &&
            (entry['password'] as String).isNotEmpty) {
          itemRepaired = true;
          warnings.add('token-password-dropped');
        }
        final rawUrls = entry['urls'];
        if (rawUrls is List && rawUrls.any((value) => '$value'.isNotEmpty)) {
          itemRepaired = true;
          warnings.add('token-urls-dropped');
        }
        if (type == OtpType.steam &&
            (algorithm != OtpHashAlgorithm.sha1 ||
                (rawDigits != null && rawDigits != 5))) {
          itemRepaired = true;
        }

        items.add(
          VaultItem.tokenItem(
            id: id,
            title: title,
            token: TokenData(
              secret: TotpSecret(
                type: type,
                secret: secret,
                algorithm: type == OtpType.steam
                    ? OtpHashAlgorithm.sha1
                    : algorithm,
                digits: type == OtpType.steam
                    ? 5
                    : ((rawDigits ?? 6) == 8 ? 8 : 6),
                period: type == OtpType.steam
                    ? 30
                    : ((rawPeriod != null && rawPeriod >= 1 && rawPeriod <= 300)
                          ? rawPeriod
                          : 30),
                counter: rawCounter < 0 ? 0 : rawCounter,
              ),
              account: entry['username'] as String? ?? '',
              notes: entry['notes'] as String? ?? '',
            ),
            favorite: favorite,
            icon: icon,
            createdAt: itemCreatedAt,
            updatedAt: itemUpdatedAt,
            deletedAt: deletedAt,
          ),
        );
      } else {
        if (entry['totp'] != null) {
          itemRepaired = true;
          warnings.add('login-totp-dropped');
        }
        final rawUrls = entry['urls'];
        final urls = <String>[];
        final seen = <String>{};
        if (rawUrls is List) {
          for (final value in rawUrls) {
            if (value is! String) {
              itemRepaired = true;
              continue;
            }
            final trimmed = value.trim();
            if (trimmed.isEmpty) continue;
            if (seen.add(trimmed)) {
              urls.add(trimmed);
            } else {
              itemRepaired = true;
            }
          }
        } else if (rawUrls != null) {
          itemRepaired = true;
        }
        final password = entry['password'];
        if (password != null && password is! String) itemRepaired = true;

        items.add(
          VaultItem.loginItem(
            id: id,
            title: title,
            login: LoginData(
              username: entry['username'] as String? ?? '',
              password: password is String ? password : '',
              urls: urls,
              notes: entry['notes'] as String? ?? '',
            ),
            favorite: favorite,
            icon: icon,
            createdAt: itemCreatedAt,
            updatedAt: itemUpdatedAt,
            deletedAt: deletedAt,
          ),
        );
      }

      if (itemRepaired) repaired++;
    }
  } else if (rawItems != null) {
    warnings.add('items-not-list');
  }

  return VaultDecoded(
    data: VaultData(
      schemaVersion: VaultData.currentSchemaVersion,
      vaultId: vaultId,
      createdAt: createdAt,
      items: items,
    ),
    migration: VaultMigrationReport(
      total: rawItems is List ? rawItems.length : 0,
      migrated: items.length,
      skipped: skipped,
      repaired: repaired,
      warnings: List<String>.unmodifiable(warnings),
    ),
  );
}

DateTime _fallbackDate(
  Object? raw,
  DateTime fallback,
  void Function() markRepaired,
) {
  if (raw == null) return fallback;
  markRepaired();
  return fallback;
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

DateTime? _migrateDeletedAt(Object? value, void Function() markRepaired) {
  if (value == null) return null;
  final parsed = _parseDate(value);
  if (parsed == null) {
    markRepaired();
    return null;
  }
  return parsed;
}

IconRef? _migrateIcon(Object? value, void Function() markRepaired) {
  if (value is! Map) {
    if (value != null) markRepaired();
    return null;
  }
  try {
    return IconRef.fromJson(value.cast<String, Object?>());
  } on Object {
    markRepaired();
    return null;
  }
}

OtpType _otpType(Object? value) {
  return switch (value) {
    'hotp' => OtpType.hotp,
    'steam' => OtpType.steam,
    _ => OtpType.totp,
  };
}

OtpHashAlgorithm _algorithm(Object? value) {
  return switch ((value as String? ?? '').toUpperCase()) {
    'SHA256' => OtpHashAlgorithm.sha256,
    'SHA512' => OtpHashAlgorithm.sha512,
    _ => OtpHashAlgorithm.sha1,
  };
}

bool _validBase32(String value) {
  try {
    base32Decode(value);
    return true;
  } on FormatException {
    return false;
  }
}
