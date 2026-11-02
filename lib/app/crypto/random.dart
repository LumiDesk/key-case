import 'dart:math';
import 'dart:typed_data';

final Random _secureRandom = Random.secure();

/// 密码学安全随机字节。
Uint8List randomBytes(int length) {
  if (length <= 0) {
    throw ArgumentError.value(length, 'length', 'must be positive');
  }
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = _secureRandom.nextInt(256);
  }
  return bytes;
}

/// 生成随机 UUID v4 字符串。条目标识不承载语义，只用于稳定引用。
String newId() {
  final bytes = randomBytes(16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = StringBuffer();
  for (var i = 0; i < bytes.length; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) hex.write('-');
    hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
  }
  return hex.toString();
}
