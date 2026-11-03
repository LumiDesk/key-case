import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/scrypt.dart';

import '../crypto/aead.dart';
import '../crypto/base32.dart';
import '../models/models.dart';

/// Aegis 导出文件解析失败。code 供 UI 选择文案。
enum AegisErrorCode {
  notAegis,
  passwordRequired,
  wrongPassword,
  unsupported,
  tooLarge,
}

class AegisImportException implements Exception {
  const AegisImportException(this.code, [this.detail]);

  final AegisErrorCode code;
  final String? detail;

  @override
  String toString() =>
      'AegisImportException(${code.name})${detail == null ? '' : ': $detail'}';
}

class AegisImportResult {
  const AegisImportResult({required this.items, required this.skipped});

  final List<VaultItem> items;

  /// Aegis 里没有动态令牌密钥的条目。
  final int skipped;
}

const int _maxFileBytes = 64 * 1024 * 1024;
const int _maxScryptN = 1 << 20;
const int _maxScryptR = 32;
const int _maxScryptP = 16;
const int _maxScryptMemoryBytes = 256 * 1024 * 1024;
const int _passwordSlotType = 1;

/// 解析 Aegis 保险库导出（明文 JSON 或口令加密的 JSON）。
///
/// Aegis 格式：
///   { version, header: { slots: [...], params: { nonce, tag } }, db: base64 | object }
/// 口令槽位用 scrypt 派生密钥，再用 AES-256-GCM 解出 master key；正文同样用
/// AES-256-GCM，nonce 与 tag 分别存在头里（不是拼接在密文末尾）。
/// scrypt 很重，整个解析放在 isolate 里跑。
Future<AegisImportResult> importAegisVault(
  Uint8List bytes, {
  String? password,
  String fallbackTitle = '未命名',
}) {
  // 顶层函数里的闭包只捕获参数，不会把调用方上下文一起带进 isolate。
  return Isolate.run(() => _importAegis(bytes, password, fallbackTitle));
}

Future<AegisImportResult> _importAegis(
  Uint8List bytes,
  String? password,
  String fallbackTitle,
) async {
  if (bytes.length > _maxFileBytes) {
    throw const AegisImportException(AegisErrorCode.tooLarge);
  }

  final Map<String, Object?> root;
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const AegisImportException(AegisErrorCode.notAegis);
    }
    root = decoded.cast<String, Object?>();
  } on AegisImportException {
    rethrow;
  } catch (error) {
    throw AegisImportException(AegisErrorCode.notAegis, '$error');
  }

  final header = root['header'];
  final slots = header is Map ? header['slots'] : null;

  final Map<String, Object?> db;
  if (slots is! List || slots.isEmpty) {
    final rawDb = root['db'];
    if (rawDb is! Map) {
      throw const AegisImportException(AegisErrorCode.notAegis);
    }
    db = rawDb.cast<String, Object?>();
  } else {
    if (password == null || password.isEmpty) {
      throw const AegisImportException(AegisErrorCode.passwordRequired);
    }
    final encrypted = root['db'];
    if (encrypted is! String || header is! Map) {
      throw const AegisImportException(AegisErrorCode.notAegis);
    }
    final params = header['params'];
    if (params is! Map) {
      throw const AegisImportException(AegisErrorCode.notAegis);
    }
    db = await _decryptDatabase(
      encryptedBase64: encrypted,
      params: params.cast<String, Object?>(),
      slots: slots,
      password: password,
    );
  }

  return _parseDatabase(db, fallbackTitle);
}

Future<Map<String, Object?>> _decryptDatabase({
  required String encryptedBase64,
  required Map<String, Object?> params,
  required List<Object?> slots,
  required String password,
}) async {
  final ciphertext = _decodeBase64(encryptedBase64);
  final nonce = _decodeHex(params['nonce']);
  final tag = _decodeHex(params['tag']);
  if (nonce == null || tag == null) {
    throw const AegisImportException(AegisErrorCode.notAegis);
  }

  Object? lastError;
  for (final rawSlot in slots) {
    if (rawSlot is! Map) continue;
    final slot = rawSlot.cast<String, Object?>();
    if ((slot['type'] as num?)?.toInt() != _passwordSlotType) continue;
    try {
      final masterKey = await _decryptSlot(slot, password);
      final plaintext = await _gcmDecrypt(masterKey, ciphertext, nonce, tag);
      final decoded = jsonDecode(utf8.decode(plaintext));
      if (decoded is! Map) {
        throw const AegisImportException(AegisErrorCode.notAegis);
      }
      return decoded.cast<String, Object?>();
    } on AegisImportException catch (error) {
      lastError = error;
    } catch (error) {
      lastError = error;
    }
  }
  throw AegisImportException(AegisErrorCode.wrongPassword, '$lastError');
}

Future<Uint8List> _decryptSlot(
  Map<String, Object?> slot,
  String password,
) async {
  final n = (slot['n'] as num?)?.toInt();
  final r = (slot['r'] as num?)?.toInt();
  final p = (slot['p'] as num?)?.toInt();
  if (n == null || r == null || p == null) {
    throw const AegisImportException(AegisErrorCode.notAegis);
  }
  // 恶意文件可以用超大 scrypt 参数把内存打满，先按上限拒绝。
  if (n < 2 || n > _maxScryptN || (n & (n - 1)) != 0) {
    throw const AegisImportException(AegisErrorCode.unsupported);
  }
  if (r < 1 || r > _maxScryptR || p < 1 || p > _maxScryptP) {
    throw const AegisImportException(AegisErrorCode.unsupported);
  }
  if (128 * n * r > _maxScryptMemoryBytes) {
    throw const AegisImportException(AegisErrorCode.unsupported);
  }

  final salt = _decodeHex(slot['salt']);
  final encryptedKey = _decodeHex(slot['key']);
  final keyParams = slot['key_params'];
  if (salt == null || encryptedKey == null || keyParams is! Map) {
    throw const AegisImportException(AegisErrorCode.notAegis);
  }
  final nonce = _decodeHex(keyParams['nonce']);
  final tag = _decodeHex(keyParams['tag']);
  if (nonce == null || tag == null) {
    throw const AegisImportException(AegisErrorCode.notAegis);
  }

  final derivator = Scrypt()..init(ScryptParameters(n, r, p, 32, salt));
  final derived = derivator.process(Uint8List.fromList(utf8.encode(password)));
  return _gcmDecrypt(derived, encryptedKey, nonce, tag);
}

Future<Uint8List> _gcmDecrypt(
  Uint8List key,
  Uint8List ciphertext,
  Uint8List nonce,
  Uint8List tag,
) {
  final combined = Uint8List(ciphertext.length + tag.length)
    ..setAll(0, ciphertext)
    ..setAll(ciphertext.length, tag);
  return openBytes(
    key: key,
    sealed: SealedBytes(nonce: nonce, cipherText: combined),
    aad: const <int>[],
  );
}

AegisImportResult _parseDatabase(
  Map<String, Object?> db,
  String fallbackTitle,
) {
  final entries = db['entries'];
  if (entries is! List) {
    throw const AegisImportException(AegisErrorCode.notAegis);
  }

  final now = DateTime.now().toUtc();
  final items = <VaultItem>[];
  var skipped = 0;
  var index = 0;

  for (final rawEntry in entries) {
    if (rawEntry is! Map) {
      skipped++;
      continue;
    }
    final item = _convertEntry(
      rawEntry.cast<String, Object?>(),
      now,
      'aegis-${now.microsecondsSinceEpoch}-${index++}',
      fallbackTitle,
    );
    if (item == null) {
      skipped++;
    } else {
      items.add(item);
    }
  }
  return AegisImportResult(items: items, skipped: skipped);
}

VaultItem? _convertEntry(
  Map<String, Object?> entry,
  DateTime now,
  String id,
  String fallbackTitle,
) {
  final info = entry['info'];
  if (info is! Map) return null;
  final infoMap = info.cast<String, Object?>();
  final secret = (infoMap['secret'] as String? ?? '').trim();
  if (secret.isEmpty) return null;

  final otpType = switch ((entry['type'] as String?)?.toLowerCase()) {
    'hotp' => OtpType.hotp,
    'steam' => OtpType.steam,
    _ => OtpType.totp,
  };
  final digits = (infoMap['digits'] as num?)?.toInt();
  final period = (infoMap['period'] as num?)?.toInt();
  final counter = int.tryParse('${infoMap['counter'] ?? 0}') ?? 0;
  final algorithm = switch ((infoMap['algo'] as String?)?.toUpperCase()) {
    'SHA256' => OtpHashAlgorithm.sha256,
    'SHA512' => OtpHashAlgorithm.sha512,
    _ => OtpHashAlgorithm.sha1,
  };

  final name = (entry['name'] as String? ?? '').trim();
  final issuer = (entry['issuer'] as String? ?? '').trim();
  final notes = (entry['note'] as String? ?? '').trim();
  final title = issuer.isNotEmpty
      ? issuer
      : (name.isNotEmpty ? name : fallbackTitle);

  return VaultItem.tokenItem(
    id: id,
    title: title,
    token: TokenData(
      secret: TotpSecret(
        type: otpType,
        secret: normalizeBase32(secret),
        algorithm: otpType == OtpType.steam ? OtpHashAlgorithm.sha1 : algorithm,
        digits: otpType == OtpType.steam ? 5 : ((digits ?? 6) == 8 ? 8 : 6),
        period: otpType == OtpType.steam
            ? 30
            : ((period != null && period >= 1 && period <= 300) ? period : 30),
        counter: counter < 0 ? 0 : counter,
      ),
      account: name,
      notes: notes,
    ),
    favorite: entry['favorite'] == true,
    createdAt: now,
    updatedAt: now,
  );
}

Uint8List? _decodeHex(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final text = value.length.isOdd ? '0$value' : value;
  try {
    final out = Uint8List(text.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(text.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  } on FormatException {
    return null;
  }
}

Uint8List _decodeBase64(String value) {
  try {
    return base64Decode(value.trim());
  } on FormatException {
    throw const AegisImportException(AegisErrorCode.notAegis);
  }
}
