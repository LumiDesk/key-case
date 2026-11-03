/// Base32（RFC 4648）编解码。
///
/// otpauth / Aegis / 手动输入的密钥都用这种编码；解码要容忍小写、空格、
/// 分组连字符和尾部 `=`，否则用户从别处粘贴的密钥会失败。
library;

import 'dart:typed_data';

const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

Uint8List base32Decode(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toUpperCase().split('')) {
    if (rune == '=' || rune == ' ' || rune == '-' || rune == '\t') continue;
    buffer.write(rune);
  }
  final text = buffer.toString();
  if (text.isEmpty) {
    throw const FormatException('Base32 内容为空');
  }

  final out = BytesBuilder(copy: false);
  var bitBuffer = 0;
  var bitCount = 0;
  for (var i = 0; i < text.length; i++) {
    final value = _alphabet.indexOf(text[i]);
    if (value < 0) {
      throw FormatException('非法的 Base32 字符：${text[i]}', input, i);
    }
    bitBuffer = ((bitBuffer & 0xFFFFF) << 5) | value;
    bitCount += 5;
    if (bitCount >= 8) {
      bitCount -= 8;
      out.addByte((bitBuffer >> bitCount) & 0xFF);
    }
  }
  return out.toBytes();
}

String base32Encode(Uint8List bytes) {
  final out = StringBuffer();
  var bitBuffer = 0;
  var bitCount = 0;
  for (final byte in bytes) {
    bitBuffer = ((bitBuffer & 0xFFFF) << 8) | byte;
    bitCount += 8;
    while (bitCount >= 5) {
      bitCount -= 5;
      out.write(_alphabet[(bitBuffer >> bitCount) & 0x1F]);
    }
  }
  if (bitCount > 0) {
    out.write(_alphabet[(bitBuffer << (5 - bitCount)) & 0x1F]);
  }
  return out.toString();
}

/// 规范化用户输入的密钥：去空格、连字符、填充符并转大写。
String normalizeBase32(String input) {
  return input.toUpperCase().replaceAll(RegExp(r'[\s\-=]'), '');
}
