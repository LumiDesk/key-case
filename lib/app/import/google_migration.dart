import 'dart:convert';
import 'dart:typed_data';

import '../crypto/base32.dart';
import '../models/models.dart';

/// 解析 Google Authenticator「导出账号」二维码里的 protobuf。
///
/// URI：`otpauth-migration://offline?data=<base64url(protobuf)>`
/// 手写最小的 protobuf 读取器：只需要 varint 与 length-delimited 两种线型，
/// 不值得为此引入 protobuf 运行时。
class GoogleMigrationEntry {
  const GoogleMigrationEntry({
    required this.type,
    required this.secret,
    this.issuer = '',
    this.account = '',
    this.algorithm = OtpHashAlgorithm.sha1,
    this.digits = 6,
    this.counter = 0,
  });

  final OtpType type;
  final String secret;
  final String issuer;
  final String account;
  final OtpHashAlgorithm algorithm;
  final int digits;
  final int counter;

  String get displayTitle =>
      issuer.isNotEmpty ? issuer : (account.isNotEmpty ? account : secret);

  VaultItem toItem(DateTime now, String id) => VaultItem.tokenItem(
    id: id,
    title: displayTitle,
    token: TokenData(
      secret: TotpSecret(
        type: type,
        secret: secret,
        algorithm: algorithm,
        digits: digits,
        period: 30,
        counter: counter,
      ),
      account: account,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

class GoogleMigrationException implements Exception {
  const GoogleMigrationException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool isGoogleMigrationLink(String raw) =>
    raw.trim().toLowerCase().startsWith('otpauth-migration://');

List<GoogleMigrationEntry> parseGoogleMigration(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'otpauth-migration') {
    throw const GoogleMigrationException('不是 Google 迁移链接');
  }
  final data = uri.queryParameters['data'];
  if (data == null || data.isEmpty) {
    throw const GoogleMigrationException('迁移链接缺少 data 参数');
  }

  final bytes = _decodeBase64Url(data);
  final entries = <GoogleMigrationEntry>[];
  final reader = _ProtoReader(bytes);
  while (reader.hasMore) {
    final tag = reader.varint();
    final field = tag >> 3;
    final wire = tag & 0x7;
    if (field == 1 && wire == 2) {
      entries.add(_parseEntry(reader.lengthDelimited()));
    } else {
      reader.skip(wire);
    }
  }
  if (entries.isEmpty) {
    throw const GoogleMigrationException('迁移数据里没有账号');
  }
  return entries;
}

GoogleMigrationEntry _parseEntry(Uint8List data) {
  Uint8List? secret;
  var name = '';
  var issuer = '';
  var algorithm = 0;
  var digits = 0;
  var type = 0;
  var counter = 0;

  final reader = _ProtoReader(data);
  while (reader.hasMore) {
    final tag = reader.varint();
    final field = tag >> 3;
    final wire = tag & 0x7;
    switch ((field, wire)) {
      case (1, 2):
        secret = reader.lengthDelimited();
      case (2, 2):
        name = utf8.decode(reader.lengthDelimited(), allowMalformed: true);
      case (3, 2):
        issuer = utf8.decode(reader.lengthDelimited(), allowMalformed: true);
      case (4, 0):
        algorithm = reader.varint();
      case (5, 0):
        digits = reader.varint();
      case (6, 0):
        type = reader.varint();
      case (7, 0):
        counter = reader.varint();
      default:
        reader.skip(wire);
    }
  }

  if (secret == null || secret.isEmpty) {
    throw const GoogleMigrationException('迁移条目缺少密钥');
  }

  return GoogleMigrationEntry(
    type: type == 1 ? OtpType.hotp : OtpType.totp,
    secret: base32Encode(secret),
    issuer: issuer,
    account: name,
    algorithm: switch (algorithm) {
      2 => OtpHashAlgorithm.sha256,
      3 => OtpHashAlgorithm.sha512,
      _ => OtpHashAlgorithm.sha1,
    },
    digits: digits == 2 ? 8 : 6,
    counter: counter,
  );
}

Uint8List _decodeBase64Url(String value) {
  var text = value.trim().replaceAll('-', '+').replaceAll('_', '/');
  final padding = text.length % 4;
  if (padding != 0) text = text.padRight(text.length + 4 - padding, '=');
  try {
    return base64Decode(text);
  } on FormatException {
    throw const GoogleMigrationException('迁移数据不是有效的 Base64');
  }
}

class _ProtoReader {
  _ProtoReader(this._bytes);

  final Uint8List _bytes;
  int _position = 0;

  bool get hasMore => _position < _bytes.length;

  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_position >= _bytes.length || shift >= 64) {
        throw const GoogleMigrationException('protobuf varint 非法');
      }
      final byte = _bytes[_position++] & 0xFF;
      result |= (byte & 0x7F) << shift;
      if (byte & 0x80 == 0) return result;
      shift += 7;
    }
  }

  Uint8List lengthDelimited() {
    final length = varint();
    if (length < 0 || _position + length > _bytes.length) {
      throw const GoogleMigrationException('protobuf 长度非法');
    }
    final result = Uint8List.sublistView(_bytes, _position, _position + length);
    _position += length;
    return Uint8List.fromList(result);
  }

  void skip(int wire) {
    switch (wire) {
      case 0:
        varint();
      case 1:
        _position += 8;
      case 2:
        lengthDelimited();
      case 5:
        _position += 4;
      default:
        throw GoogleMigrationException('不支持的 protobuf 线型：$wire');
    }
    if (_position > _bytes.length) {
      throw const GoogleMigrationException('protobuf 被截断');
    }
  }
}
