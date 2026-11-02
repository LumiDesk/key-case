import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../crypto/aead.dart';
import '../crypto/kdf.dart';
import '../logging/app_logger.dart';
import '../models/models.dart';

/// 旧 Kotlin 版容器（`TKV1`）的只读导入。
///
/// 新版本只写 `KCV1`；这里保留一段只读解码，让升级用户可以一次性把旧备份
/// 导进来（导入后会按同一个主密码创建新的 KCV1 保险库）。格式细节见
/// docs/dev/tech-decisions.md。
const String _legacyMagic = 'TKV1';
const int _legacyVersion = 1;
const int _legacyHeaderSize = 9;

class LegacyVaultException implements Exception {
  const LegacyVaultException({required this.wrongPassword, this.detail});

  final bool wrongPassword;
  final String? detail;

  @override
  String toString() => 'LegacyVaultException(wrongPassword=$wrongPassword)';
}

bool isLegacyVault(Uint8List bytes) {
  if (bytes.length < _legacyHeaderSize + 1) return false;
  return ascii.decode(bytes.sublist(0, 4), allowInvalid: true) ==
          _legacyMagic &&
      bytes[4] == _legacyVersion;
}

/// 解出旧容器里的条目；不是旧版容器返回 null。
///
/// 口令错误抛 [LegacyVaultException]（`wrongPassword: true`）。
Future<VaultData?> tryDecodeLegacyVault({
  required Uint8List bytes,
  required String password,
}) async {
  if (!isLegacyVault(bytes)) return null;

  try {
    final headerLength = ByteData.sublistView(bytes, 5, 9).getUint32(0);
    final headerEnd = _legacyHeaderSize + headerLength;
    final header = (jsonDecode(
      utf8.decode(bytes.sublist(_legacyHeaderSize, headerEnd)),
    ) as Map).cast<String, Object?>();
    final vaultId = header['vaultId'] as String? ?? '';
    final slots = (header['slots'] as List).cast<Map<String, Object?>>();
    final slot = slots.firstWhere((entry) => entry['type'] == 'password');

    final params = KdfParams.fromJson(
      (slot['kdf'] as Map).cast<String, Object?>(),
    );
    final passwordKey = await deriveArgon2idKey(
      password: password,
      salt: base64Decode(slot['salt'] as String),
      params: params,
    );
    final vaultKey = await openBytes(
      key: passwordKey,
      sealed: SealedBytes(
        nonce: base64Decode(slot['nonce'] as String),
        cipherText: base64Decode(slot['wrappedKey'] as String),
      ),
      aad: utf8.encode('$_legacyMagic|$_legacyVersion|${slot['id']}|password'),
    );
    final plaintext = await openBytes(
      key: vaultKey,
      sealed: SealedBytes(
        nonce: base64Decode(header['payloadNonce'] as String),
        cipherText: Uint8List.sublistView(bytes, headerEnd),
      ),
      aad: utf8.encode('$_legacyMagic|$_legacyVersion|$vaultId|payload'),
    );

    final root = (jsonDecode(
      utf8.decode(GZipDecoder().decodeBytes(plaintext)),
    ) as Map).cast<String, Object?>();
    final items = <VaultItem>[];
    for (final raw in (root['items'] as List? ?? const <Object?>[])) {
      if (raw is! Map) continue;
      items.add(_convertItem(raw.cast<String, Object?>()));
    }

    return VaultData(
      vaultId: vaultId,
      createdAt:
          DateTime.tryParse(root['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      items: items,
    );
  } on AeadException catch (error) {
    AppLogger.warn('legacy vault decrypt failed: $error');
    throw const LegacyVaultException(wrongPassword: true);
  } catch (error) {
    AppLogger.error('legacy vault import failed', error);
    throw LegacyVaultException(wrongPassword: false, detail: '$error');
  }
}

VaultItem _convertItem(Map<String, Object?> raw) {
  final totp = raw['totp'];
  final icon = raw['icon'];
  final iconValue = icon is Map ? (icon['value'] as String? ?? '') : '';
  final urls = (raw['urls'] as List? ?? const <Object?>[])
      .whereType<String>()
      .where((url) => url.trim().isNotEmpty)
      .toList();

  return VaultItem(
    id: (raw['id'] as String?)?.isNotEmpty == true
        ? raw['id'] as String
        : 'legacy-${raw.hashCode}',
    kind: raw['kind'] == 'totp' ? ItemKind.totp : ItemKind.login,
    title: (raw['title'] as String? ?? '').trim(),
    username: (raw['username'] as String? ?? '').trim(),
    password: raw['password'] as String? ?? '',
    urls: urls,
    notes: raw['notes'] as String? ?? '',
    totp: totp is Map ? _convertTotp(totp.cast<String, Object?>()) : null,
    icon: iconValue.isEmpty ? null : IconRef(name: iconValue),
    favorite: raw['favorite'] == true,
    createdAt: _date(raw['createdAt']),
    updatedAt: _date(raw['updatedAt']),
    deletedAt: raw['deletedAt'] == null ? null : _date(raw['deletedAt']),
  );
}

TotpSecret _convertTotp(Map<String, Object?> raw) {
  return TotpSecret(
    type: switch ((raw['type'] as String? ?? 'totp').toLowerCase()) {
      'hotp' => OtpType.hotp,
      'steam' => OtpType.steam,
      _ => OtpType.totp,
    },
    secret: (raw['secret'] as String? ?? '').toUpperCase().replaceAll(' ', ''),
    algorithm: switch ((raw['algorithm'] as String? ?? 'SHA1').toUpperCase()) {
      'SHA256' => OtpHashAlgorithm.sha256,
      'SHA512' => OtpHashAlgorithm.sha512,
      _ => OtpHashAlgorithm.sha1,
    },
    digits: (raw['digits'] as num?)?.toInt() ?? 6,
    period: (raw['period'] as num?)?.toInt() ?? 30,
    counter: (raw['counter'] as num?)?.toInt() ?? 0,
  );
}

DateTime _date(Object? value) =>
    DateTime.tryParse(value is String ? value : '')?.toUtc() ??
    DateTime.now().toUtc();
