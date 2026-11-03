import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../crypto/aead.dart';
import '../crypto/kdf.dart';
import '../crypto/random.dart';
import '../models/models.dart';
import 'vault_migrations.dart';

/// 失败原因分类。UI 依赖 code 选择文案，不解析 message（message 只用于日志）。
enum VaultErrorCode {
  wrongPassword,
  corrupted,
  unsupportedVersion,
  notAVault,
  locked,
  tooLarge,
  migration,
  unknown,
}

/// 容器格式错误、口令错误、数据损坏都归一成这个异常。
class VaultFormatException implements Exception {
  const VaultFormatException(
    this.message, {
    this.code = VaultErrorCode.unknown,
  });

  final String message;
  final VaultErrorCode code;

  @override
  String toString() => message;
}

class KeySlot {
  const KeySlot({
    required this.id,
    required this.type,
    required this.salt,
    required this.nonce,
    required this.wrappedKey,
  });

  final String id;

  /// 目前只有 `password`；生物识别解锁的密钥包在 Android Keystore，不在文件里。
  final String type;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List wrappedKey;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type,
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonce),
    'wrappedKey': base64Encode(wrappedKey),
  };

  factory KeySlot.fromJson(Map<String, Object?> json) {
    return KeySlot(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      salt: base64Decode(json['salt'] as String? ?? ''),
      nonce: base64Decode(json['nonce'] as String? ?? ''),
      wrappedKey: base64Decode(json['wrappedKey'] as String? ?? ''),
    );
  }
}

class VaultHeader {
  const VaultHeader({
    required this.formatVersion,
    required this.vaultId,
    required this.createdAt,
    required this.kdf,
    required this.slots,
    required this.payloadNonce,
  });

  final int formatVersion;
  final String vaultId;
  final DateTime createdAt;
  final KdfParams kdf;
  final List<KeySlot> slots;
  final Uint8List payloadNonce;
}

/// 已解锁的保险库会话。持有明文 vault key，用完后必须调用 [close]。
class UnlockedVault {
  UnlockedVault({
    required this.header,
    required this.vaultKey,
    required this.data,
  });

  final VaultHeader header;
  final Uint8List vaultKey;
  final VaultData data;

  UnlockedVault withData(VaultData next) =>
      UnlockedVault(header: header, vaultKey: vaultKey, data: next);

  /// 清零内存里的密钥。Dart 无法保证 GC 后不留副本，但至少缩短生命周期。
  void close() {
    vaultKey.fillRange(0, vaultKey.length, 0);
  }
}

class CreatedVault {
  const CreatedVault({required this.bytes, required this.session});

  final Uint8List bytes;
  final UnlockedVault session;
}

/// 单文件加密容器。
///
/// 布局：
///   magic "KCV1" (4)
///   format version (1)
///   header length (4, big endian)
///   header JSON (UTF-8)
///   payload 密文（AES-256-GCM，含 tag）
///
/// payload = AES-GCM(gzip(JSON(VaultData)))，密钥是随机的 256 位 vault key；
/// vault key 再由 Argon2id 派生的口令密钥包在 key slot 里。改主密码会换新 slot
/// 并用同一 vault key 重新加密正文（新 nonce），vault key 不变。
class VaultContainer {
  const VaultContainer._();

  static const String magic = 'KCV1';
  static const int formatVersion = 1;
  static const int fileHeaderSize = 9;
  static const String passwordSlotType = 'password';

  static const int _maxHeaderBytes = 1024 * 1024;
  static const int _maxPayloadBytes = 64 * 1024 * 1024;
  static const int _maxPlaintextBytes = 64 * 1024 * 1024;

  static Future<CreatedVault> create({
    required String password,
    required VaultData data,
    KdfParams kdfParams = const KdfParams(),
  }) async {
    if (password.isEmpty) {
      throw const VaultFormatException('主密码不能为空');
    }
    final vaultId = newId();
    final now = DateTime.now().toUtc();
    final vaultKey = randomBytes(32);
    final salt = randomBytes(16);
    final slotId = newId();

    final passwordKey = await deriveArgon2idKey(
      password: password,
      salt: salt,
      params: kdfParams,
    );
    final wrapped = await sealBytes(
      key: passwordKey,
      plaintext: vaultKey,
      aad: slotAad(slotId, passwordSlotType),
    );

    final slot = KeySlot(
      id: slotId,
      type: passwordSlotType,
      salt: salt,
      nonce: wrapped.nonce,
      wrappedKey: wrapped.cipherText,
    );

    final payload = (data.copyWith(
      vaultId: vaultId,
      createdAt: now,
      schemaVersion: VaultData.currentSchemaVersion,
    )).toJson();
    final encrypted = await _encryptPayload(
      vaultKey: vaultKey,
      payload: payload,
      vaultId: vaultId,
    );

    final header = VaultHeader(
      formatVersion: formatVersion,
      vaultId: vaultId,
      createdAt: now,
      kdf: kdfParams,
      slots: <KeySlot>[slot],
      payloadNonce: encrypted.nonce,
    );

    return CreatedVault(
      bytes: _assemble(header, encrypted.cipherText),
      session: UnlockedVault(
        header: header,
        vaultKey: vaultKey,
        data: VaultData.fromJson(payload),
      ),
    );
  }

  static Future<UnlockedVault> unlock({
    required String password,
    required Uint8List bytes,
  }) async {
    final parsed = _parse(bytes);
    final slot = parsed.header.slots.firstWhere(
      (slot) => slot.type == passwordSlotType,
      orElse: () => throw const VaultFormatException(
        '保险库缺少口令槽位',
        code: VaultErrorCode.corrupted,
      ),
    );

    final passwordKey = await deriveArgon2idKey(
      password: password,
      salt: slot.salt,
      params: parsed.header.kdf,
    );
    final vaultKey = await _openSlot(passwordKey: passwordKey, slot: slot);

    return _openPayload(
      header: parsed.header,
      ciphertext: parsed.ciphertext,
      vaultKey: vaultKey,
    );
  }

  /// 用已解包的 vault key 直接解密正文（生物识别解锁路径）。
  static Future<UnlockedVault> unlockWithVaultKey({
    required Uint8List bytes,
    required Uint8List vaultKey,
  }) async {
    final parsed = _parse(bytes);
    return _openPayload(
      header: parsed.header,
      ciphertext: parsed.ciphertext,
      vaultKey: vaultKey,
    );
  }

  /// 用新口令替换口令槽位；vault key 与正文重新加密。
  static Future<CreatedVault> changePassword({
    required UnlockedVault session,
    required String newPassword,
    KdfParams kdfParams = const KdfParams(),
  }) async {
    if (newPassword.isEmpty) {
      throw const VaultFormatException('主密码不能为空');
    }
    final salt = randomBytes(16);
    final slotId = newId();
    final passwordKey = await deriveArgon2idKey(
      password: newPassword,
      salt: salt,
      params: kdfParams,
    );
    final wrapped = await sealBytes(
      key: passwordKey,
      plaintext: session.vaultKey,
      aad: slotAad(slotId, passwordSlotType),
    );
    final slot = KeySlot(
      id: slotId,
      type: passwordSlotType,
      salt: salt,
      nonce: wrapped.nonce,
      wrappedKey: wrapped.cipherText,
    );
    final encrypted = await _encryptPayload(
      vaultKey: session.vaultKey,
      payload: session.data.toJson(),
      vaultId: session.header.vaultId,
    );
    final header = VaultHeader(
      formatVersion: session.header.formatVersion,
      vaultId: session.header.vaultId,
      createdAt: session.header.createdAt,
      kdf: kdfParams,
      slots: <KeySlot>[slot],
      payloadNonce: encrypted.nonce,
    );

    return CreatedVault(
      bytes: _assemble(header, encrypted.cipherText),
      // 新会话持有独立的 key 副本：调用方可以立即 close 旧会话，
      // 共享同一个数组会把仍在使用的密钥清零。
      session: UnlockedVault(
        header: header,
        vaultKey: Uint8List.fromList(session.vaultKey),
        data: session.data,
      ),
    );
  }

  /// 用当前会话的 vault key 重新加密正文（每次保存都换新 nonce）。
  static Future<Uint8List> seal(UnlockedVault session) async {
    if (session.data.vaultId != session.header.vaultId) {
      throw const VaultFormatException('保险库标识不一致');
    }
    final encrypted = await _encryptPayload(
      vaultKey: session.vaultKey,
      payload: session.data.toJson(),
      vaultId: session.header.vaultId,
    );
    final header = VaultHeader(
      formatVersion: session.header.formatVersion,
      vaultId: session.header.vaultId,
      createdAt: session.header.createdAt,
      kdf: session.header.kdf,
      slots: session.header.slots,
      payloadNonce: encrypted.nonce,
    );
    return _assemble(header, encrypted.cipherText);
  }

  static VaultHeader inspect(Uint8List bytes) => _parse(bytes).header;

  // ---------------------------------------------------------------------------

  static Future<({Uint8List nonce, Uint8List cipherText})> _encryptPayload({
    required Uint8List vaultKey,
    required Map<String, Object?> payload,
    required String vaultId,
  }) async {
    final plaintext = Uint8List.fromList(
      GZipEncoder().encode(utf8.encode(jsonEncode(payload))),
    );
    final sealed = await sealBytes(
      key: vaultKey,
      plaintext: plaintext,
      aad: payloadAad(vaultId),
    );
    return (nonce: sealed.nonce, cipherText: sealed.cipherText);
  }

  static Future<UnlockedVault> _openPayload({
    required VaultHeader header,
    required Uint8List ciphertext,
    required Uint8List vaultKey,
  }) async {
    final plaintext = await _decryptPayload(
      vaultKey: vaultKey,
      header: header,
      ciphertext: ciphertext,
    );
    final decoded = _decodePayload(plaintext);
    if (decoded.vaultId != header.vaultId) {
      throw const VaultFormatException('保险库标识不一致');
    }
    return UnlockedVault(
      header: header,
      vaultKey: Uint8List.fromList(vaultKey),
      data: decoded,
    );
  }

  static Future<Uint8List> _decryptPayload({
    required Uint8List vaultKey,
    required VaultHeader header,
    required Uint8List ciphertext,
  }) async {
    final Uint8List deflated;
    try {
      deflated = await openBytes(
        key: vaultKey,
        sealed: SealedBytes(nonce: header.payloadNonce, cipherText: ciphertext),
        aad: payloadAad(header.vaultId),
      );
    } on AeadException {
      throw const VaultFormatException(
        '口令错误或保险库已损坏',
        code: VaultErrorCode.corrupted,
      );
    }
    try {
      final inflated = GZipDecoder().decodeBytes(
        deflated,
        maxOutputSize: _maxPlaintextBytes,
      );
      return Uint8List.fromList(inflated);
    } on ArchiveLimitException {
      throw const VaultFormatException(
        '保险库内容过大',
        code: VaultErrorCode.tooLarge,
      );
    } catch (error) {
      throw const VaultFormatException(
        '保险库正文无法解压',
        code: VaultErrorCode.corrupted,
      );
    }
  }

  static VaultData _decodePayload(Uint8List plaintext) {
    try {
      final decoded = jsonDecode(utf8.decode(plaintext));
      if (decoded is! Map) {
        throw const VaultFormatException('保险库正文格式不正确');
      }
      return VaultMigrations.decode(decoded.cast<String, Object?>());
    } on VaultFormatException {
      rethrow;
    } catch (error) {
      throw VaultFormatException('保险库正文无法解析：$error');
    }
  }

  static Future<Uint8List> _openSlot({
    required Uint8List passwordKey,
    required KeySlot slot,
  }) async {
    try {
      return await openBytes(
        key: passwordKey,
        sealed: SealedBytes(nonce: slot.nonce, cipherText: slot.wrappedKey),
        aad: slotAad(slot.id, slot.type),
      );
    } on AeadException {
      throw const VaultFormatException(
        '主密码错误',
        code: VaultErrorCode.wrongPassword,
      );
    }
  }

  static ({VaultHeader header, Uint8List ciphertext}) _parse(Uint8List bytes) {
    if (bytes.length < fileHeaderSize) {
      throw const VaultFormatException(
        '文件太小，不是有效的保险库',
        code: VaultErrorCode.notAVault,
      );
    }
    final magicText = ascii.decode(bytes.sublist(0, 4), allowInvalid: true);
    if (magicText != magic) {
      throw const VaultFormatException(
        '不是有效的保险库文件',
        code: VaultErrorCode.notAVault,
      );
    }
    final version = bytes[4];
    if (version != formatVersion) {
      throw VaultFormatException(
        '不支持的保险库版本：$version',
        code: VaultErrorCode.unsupportedVersion,
      );
    }
    final headerLength = ByteData.sublistView(bytes, 5, 9).getUint32(0);
    if (headerLength <= 0 || headerLength > _maxHeaderBytes) {
      throw const VaultFormatException('保险库头长度不合法');
    }
    final headerEnd = fileHeaderSize + headerLength;
    if (headerEnd > bytes.length) {
      throw const VaultFormatException('保险库头被截断');
    }
    final payloadLength = bytes.length - headerEnd;
    if (payloadLength <= 0 || payloadLength > _maxPayloadBytes) {
      throw const VaultFormatException('保险库正文长度不合法');
    }

    final VaultHeader header;
    try {
      final decoded = jsonDecode(utf8.decode(bytes.sublist(9, headerEnd)));
      if (decoded is! Map) {
        throw const VaultFormatException('保险库头格式不正确');
      }
      header = _headerFromJson(decoded.cast<String, Object?>());
    } on VaultFormatException {
      rethrow;
    } catch (error) {
      throw VaultFormatException(
        '保险库头无法解析：$error',
        code: VaultErrorCode.corrupted,
      );
    }

    return (
      header: header,
      ciphertext: Uint8List.sublistView(bytes, headerEnd),
    );
  }

  static VaultHeader _headerFromJson(Map<String, Object?> json) {
    final slots = <KeySlot>[];
    final rawSlots = json['slots'];
    if (rawSlots is! List) {
      throw const VaultFormatException(
        '保险库缺少密钥槽位',
        code: VaultErrorCode.corrupted,
      );
    }
    for (final raw in rawSlots) {
      if (raw is! Map) continue;
      slots.add(KeySlot.fromJson(raw.cast<String, Object?>()));
    }
    if (slots.isEmpty) {
      throw const VaultFormatException(
        '保险库缺少密钥槽位',
        code: VaultErrorCode.corrupted,
      );
    }
    if (slots.length > 8) {
      throw const VaultFormatException(
        '保险库密钥槽位过多',
        code: VaultErrorCode.corrupted,
      );
    }
    for (final slot in slots) {
      if (slot.id.isEmpty ||
          slot.type.isEmpty ||
          slot.salt.length < 8 ||
          slot.nonce.length != 12 ||
          slot.wrappedKey.length < macLength) {
        throw const VaultFormatException(
          '保险库密钥槽位格式不正确',
          code: VaultErrorCode.corrupted,
        );
      }
    }
    final vaultId = json['vaultId'] as String? ?? '';
    if (vaultId.isEmpty) {
      throw const VaultFormatException(
        '保险库缺少标识',
        code: VaultErrorCode.corrupted,
      );
    }
    final payloadNonce = base64Decode(json['payloadNonce'] as String? ?? '');
    if (payloadNonce.length != 12) {
      throw const VaultFormatException(
        '保险库正文 nonce 长度不正确',
        code: VaultErrorCode.corrupted,
      );
    }
    return VaultHeader(
      formatVersion: (json['formatVersion'] as num?)?.toInt() ?? 0,
      vaultId: vaultId,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      kdf: KdfParams.fromJson(
        (json['kdf'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      slots: slots,
      payloadNonce: payloadNonce,
    );
  }

  static Uint8List _assemble(VaultHeader header, Uint8List ciphertext) {
    final headerJson = <String, Object?>{
      'formatVersion': header.formatVersion,
      'vaultId': header.vaultId,
      'createdAt': header.createdAt.toUtc().toIso8601String(),
      'kdf': header.kdf.toJson(),
      'slots': header.slots.map((slot) => slot.toJson()).toList(),
      'payloadNonce': base64Encode(header.payloadNonce),
    };
    final headerBytes = utf8.encode(jsonEncode(headerJson));
    final out = Uint8List(
      fileHeaderSize + headerBytes.length + ciphertext.length,
    );
    out.setAll(0, ascii.encode(magic));
    out[4] = formatVersion;
    ByteData.sublistView(out, 5, 9).setUint32(0, headerBytes.length);
    out.setAll(9, headerBytes);
    out.setAll(fileHeaderSize + headerBytes.length, ciphertext);
    return out;
  }

  static List<int> payloadAad(String vaultId) =>
      utf8.encode('$magic|$formatVersion|$vaultId|payload');

  static List<int> slotAad(String slotId, String type) =>
      utf8.encode('$magic|$formatVersion|$slotId|$type');
}
