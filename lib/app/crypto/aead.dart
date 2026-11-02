/// AES-256-GCM 认证加密。
///
/// 密文按「密文 || 16 字节 tag」拼接存储，与 JCE 的 AES/GCM/NoPadding 一致，
/// 调用方不需要分别处理 tag。
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'random.dart';

const int macLength = 16;

final AesGcm _aesGcm = AesGcm.with256bits();

class SealedBytes {
  const SealedBytes({required this.nonce, required this.cipherText});

  final Uint8List nonce;

  /// 密文 + tag。
  final Uint8List cipherText;
}

Future<SealedBytes> sealBytes({
  required Uint8List key,
  required Uint8List plaintext,
  required List<int> aad,
  Uint8List? nonce,
}) async {
  if (key.length != 32) {
    throw ArgumentError.value(key.length, 'key', 'AES-256 需要 32 字节密钥');
  }
  final useNonce = nonce ?? randomBytes(AesGcm.defaultNonceLength);
  final box = await _aesGcm.encrypt(
    plaintext,
    secretKey: SecretKey(key),
    nonce: useNonce,
    aad: aad,
  );
  final mac = box.mac.bytes;
  final combined = Uint8List(box.cipherText.length + mac.length);
  combined.setAll(0, box.cipherText);
  combined.setAll(box.cipherText.length, mac);
  return SealedBytes(
    nonce: Uint8List.fromList(useNonce),
    cipherText: combined,
  );
}

/// 解密失败（口令错误、数据被篡改）统一抛 [AeadException]。
class AeadException implements Exception {
  const AeadException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<Uint8List> openBytes({
  required Uint8List key,
  required SealedBytes sealed,
  required List<int> aad,
}) async {
  if (sealed.cipherText.length < macLength) {
    throw const AeadException('密文长度不合法');
  }
  final splitAt = sealed.cipherText.length - macLength;
  final box = SecretBox(
    sealed.cipherText.sublist(0, splitAt),
    nonce: sealed.nonce,
    mac: Mac(sealed.cipherText.sublist(splitAt)),
  );
  try {
    final plaintext = await _aesGcm.decrypt(
      box,
      secretKey: SecretKey(key),
      aad: aad,
    );
    return Uint8List.fromList(plaintext);
  } on SecretBoxAuthenticationError {
    throw const AeadException('认证失败：口令错误或数据已损坏');
  }
}
