// 一次性迁移工具：把旧 Kotlin 版的 TKV1 容器解密成新的 KCV1 备份。
//
// 用法：dart run tool/legacy_vault_import.dart <输入 .kcbackup> <输出 .kcbak> <旧主密码>
//
// 旧版格式（core/VaultContainer.kt）：
//   magic "TKV1" | version(1) | headerLen(u32be) | header JSON | AES-256-GCM 密文
//   AAD：payload = "TKV1|1|<vaultId>|payload"，slot = "TKV1|1|<slotId>|password"
//   正文：gzip(JSON(VaultData))，vault key 由 Argon2id 包在口令槽位里。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:keycase/app/crypto/aead.dart';
import 'package:keycase/app/crypto/kdf.dart';
import 'package:keycase/app/crypto/random.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/vault/vault_container.dart';

const String _legacyMagic = 'TKV1';
const int _legacyVersion = 1;
const int _legacyHeaderSize = 9;

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln(
      '用法: dart run tool/legacy_vault_import.dart <输入.kcbackup> <输出.kcbak> <旧主密码>',
    );
    exit(64);
  }
  final inputPath = args[0];
  final outputPath = args[1];
  final password = args[2];

  final bytes = File(inputPath).readAsBytesSync();
  final decoded = await _decodeLegacy(bytes, password);
  final data = decoded.data;

  stdout.writeln('旧库 vaultId: ${decoded.vaultId}');
  stdout.writeln('条目: ${data.items.length}（其中回收站 ${data.trashedItems.length}）');

  final created = await VaultContainer.create(password: password, data: data);
  File(outputPath).writeAsBytesSync(created.bytes);

  // 立刻回读验证，避免交出一个打不开的文件。
  final verify = await VaultContainer.unlock(
    password: password,
    bytes: created.bytes,
  );
  stdout.writeln(
    '已写出 $outputPath（${created.bytes.length} 字节），回读校验通过：'
    '${verify.data.items.length} 个条目',
  );
  verify.close();
}

class _DecodedVault {
  const _DecodedVault({required this.vaultId, required this.data});

  final String vaultId;
  final VaultData data;
}

Future<_DecodedVault> _decodeLegacy(Uint8List bytes, String password) async {
  if (ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != _legacyMagic) {
    throw StateError('不是旧版 TKV1 容器');
  }
  if (bytes[4] != _legacyVersion) {
    throw StateError('不支持的旧版容器版本: ${bytes[4]}');
  }
  final headerLength = ByteData.sublistView(bytes, 5, 9).getUint32(0);
  final headerEnd = _legacyHeaderSize + headerLength;
  final header = (jsonDecode(
    utf8.decode(bytes.sublist(_legacyHeaderSize, headerEnd)),
  ) as Map).cast<String, Object?>();
  final ciphertext = Uint8List.sublistView(bytes, headerEnd);

  final vaultId = header['vaultId'] as String? ?? '';
  final slots = (header['slots'] as List).cast<Map<String, Object?>>();
  final slot = slots.firstWhere((s) => s['type'] == 'password');

  final params = KdfParams.fromJson(
    (slot['kdf'] as Map).cast<String, Object?>(),
  );
  final salt = base64Decode(slot['salt'] as String);
  final passwordKey = await deriveArgon2idKey(
    password: password,
    salt: salt,
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
      cipherText: ciphertext,
    ),
    aad: utf8.encode('$_legacyMagic|$_legacyVersion|$vaultId|payload'),
  );

  final json = jsonDecode(utf8.decode(GZipDecoder().decodeBytes(plaintext)));
  final root = (json as Map).cast<String, Object?>();
  final items = <VaultItem>[];
  for (final raw in (root['items'] as List? ?? const <Object?>[])) {
    if (raw is! Map) continue;
    items.add(_convertItem(raw.cast<String, Object?>()));
  }

  return _DecodedVault(
    vaultId: vaultId,
    data: VaultData(
      vaultId: vaultId,
      createdAt:
          DateTime.tryParse(root['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      items: items,
    ),
  );
}

VaultItem _convertItem(Map<String, Object?> raw) {
  final totp = raw['totp'];
  final icon = raw['icon'];
  final iconValue = icon is Map ? (icon['value'] as String? ?? '') : '';
  final urls = (raw['urls'] as List? ?? const <Object?>[])
      .whereType<String>()
      .where((u) => u.trim().isNotEmpty)
      .toList();

  return VaultItem(
    id: (raw['id'] as String?)?.isNotEmpty == true
        ? raw['id'] as String
        : newId(),
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
