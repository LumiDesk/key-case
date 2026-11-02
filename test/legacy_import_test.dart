import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/crypto/aead.dart';
import 'package:keycase/app/crypto/kdf.dart';
import 'package:keycase/app/crypto/random.dart';
import 'package:keycase/app/import/legacy_tkv_importer.dart';

const KdfParams kdf = KdfParams(memoryKib: 64, iterations: 1, parallelism: 1);

Uint8List _u8(List<int> bytes) => Uint8List.fromList(bytes);
String _b64(Uint8List bytes) => base64Encode(bytes);

/// 按旧版 Kotlin 的容器布局拼一个 TKV1 文件，验证只读导入路径。
Future<Uint8List> _buildLegacyVault() async {
  const vaultId = 'legacy-vault-id';
  const slotId = 'slot-1';
  final now = DateTime.utc(2025, 10, 1).toIso8601String();
  final vaultKey = randomBytes(32);
  final salt = randomBytes(16);

  final passwordKey = await deriveArgon2idKey(
    password: 'legacy-password',
    salt: salt,
    params: kdf,
  );
  final wrapped = await sealBytes(
    key: passwordKey,
    plaintext: vaultKey,
    aad: utf8.encode('TKV1|1|$slotId|password'),
  );

  final payload = utf8.encode(
    jsonEncode(<String, Object?>{
      'schema': 1,
      'vaultId': vaultId,
      'createdAt': now,
      'items': <Object?>[
        <String, Object?>{
          'id': 'old-login',
          'kind': 'login',
          'title': 'GitHub',
          'username': 'alice',
          'password': 'secret',
          'urls': <String>['https://github.com'],
          'notes': '旧备注',
          'favorite': true,
          'createdAt': now,
          'updatedAt': now,
          'icon': <String, Object?>{'kind': 'pack', 'value': 'GitHub'},
        },
        <String, Object?>{
          'id': 'old-token',
          'kind': 'totp',
          'title': 'AWS',
          'username': 'root',
          'totp': <String, Object?>{
            'type': 'hotp',
            'secret': 'JBSWY3DPEHPK3PXP',
            'algorithm': 'SHA256',
            'digits': 8,
            'period': 30,
            'counter': 7,
          },
          'createdAt': now,
          'updatedAt': now,
        },
      ],
    }),
  );
  final compressed = Uint8List.fromList(GZipEncoder().encode(payload));
  final sealed = await sealBytes(
    key: vaultKey,
    plaintext: compressed,
    aad: utf8.encode('TKV1|1|$vaultId|payload'),
  );

  final header = utf8.encode(
    jsonEncode(<String, Object?>{
      'formatVersion': 1,
      'vaultId': vaultId,
      'createdAt': now,
      'kdf': kdf.toJson(),
      'slots': <Object?>[
        <String, Object?>{
          'id': slotId,
          'type': 'password',
          'salt': _b64(salt),
          'kdf': kdf.toJson(),
          'nonce': _b64(wrapped.nonce),
          'wrappedKey': _b64(wrapped.cipherText),
        },
      ],
      'payloadNonce': _b64(sealed.nonce),
    }),
  );

  final out = BytesBuilder();
  out.add(ascii.encode('TKV1'));
  out.addByte(1);
  final length = ByteData(4)..setUint32(0, header.length);
  out.add(length.buffer.asUint8List());
  out.add(header);
  out.add(sealed.cipherText);
  return out.toBytes();
}

void main() {
  test('识别旧版 TKV1 并解出条目', () async {
    final bytes = await _buildLegacyVault();
    expect(isLegacyVault(bytes), isTrue);

    final data = await tryDecodeLegacyVault(
      bytes: bytes,
      password: 'legacy-password',
    );
    expect(data, isNotNull);
    expect(data!.items, hasLength(2));

    final login = data.items.first;
    expect(login.title, 'GitHub');
    expect(login.username, 'alice');
    expect(login.favorite, isTrue);
    expect(login.icon?.name, 'GitHub');

    final token = data.items.last;
    expect(token.totp?.type.name, 'hotp');
    expect(token.totp?.algorithm.name, 'sha256');
    expect(token.totp?.digits, 8);
    expect(token.totp?.counter, 7);
  });

  test('新容器不会被误判成旧版', () async {
    final random = _u8(utf8.encode('KCV1\u0001\u0000\u0000\u0000\u0000'));
    expect(isLegacyVault(random), isFalse);
    expect(await tryDecodeLegacyVault(bytes: random, password: 'x'), isNull);
  });

  test('旧版口令错误抛出 wrongPassword', () async {
    final bytes = await _buildLegacyVault();
    await expectLater(
      tryDecodeLegacyVault(bytes: bytes, password: 'wrong'),
      throwsA(
        isA<LegacyVaultException>().having(
          (error) => error.wrongPassword,
          'wrongPassword',
          isTrue,
        ),
      ),
    );
  });
}
