import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/crypto/aead.dart';
import 'package:keycase/app/crypto/random.dart';
import 'package:keycase/app/import/aegis_importer.dart';
import 'package:keycase/app/import/google_migration.dart';
import 'package:keycase/app/import/import_merge.dart';
import 'package:keycase/app/models/models.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/scrypt.dart';

Uint8List utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));

String hexOf(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

const String plainAegisJson = '''
{
  "version": 1,
  "header": { "slots": null, "params": null },
  "db": {
    "entries": [
      {
        "type": "totp",
        "name": "alice",
        "issuer": "GitHub",
        "note": "work",
        "favorite": true,
        "info": { "secret": "JBSWY3DPEHPK3PXP", "algo": "SHA1", "digits": 6, "period": 30 }
      },
      {
        "type": "hotp",
        "name": "bob",
        "issuer": "Legacy",
        "info": { "secret": "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", "counter": 5 }
      },
      {
        "type": "steam",
        "name": "carol",
        "issuer": "Steam",
        "info": { "secret": "MZXW6YTBOI======" }
      },
      { "type": "totp", "name": "broken", "info": {} }
    ]
  }
}
''';

void main() {
  group('Aegis 导入', () {
    test('明文导出：解析令牌、算法、计数器并跳过坏条目', () async {
      final result = await importAegisVault(utf8Bytes(plainAegisJson));
      expect(result.items, hasLength(3));
      expect(result.skipped, 1);

      final github = result.items.first;
      expect(github.title, 'GitHub');
      expect(github.username, 'alice');
      expect(github.notes, 'work');
      expect(github.favorite, isTrue);
      expect(github.totp?.type, OtpType.totp);
      expect(github.totp?.secret, 'JBSWY3DPEHPK3PXP');

      final hotp = result.items[1];
      expect(hotp.totp?.type, OtpType.hotp);
      expect(hotp.totp?.counter, 5);

      final steam = result.items[2];
      expect(steam.totp?.type, OtpType.steam);
      expect(steam.totp?.digits, 5);
    });

    test('加密导出：正确口令可解，错误口令报错', () async {
      final payload = await _encryptedAegis(
        password: 'backup-password',
        entriesJson:
            '{"entries":[{"type":"totp","name":"dave","issuer":"AWS",'
            '"info":{"secret":"JBSWY3DPEHPK3PXP"}}]}',
      );

      final ok = await importAegisVault(payload, password: 'backup-password');
      expect(ok.items, hasLength(1));
      expect(ok.items.first.title, 'AWS');

      await expectLater(
        importAegisVault(payload, password: 'wrong'),
        throwsA(
          isA<AegisImportException>().having(
            (error) => error.code,
            'code',
            AegisErrorCode.wrongPassword,
          ),
        ),
      );

      await expectLater(
        importAegisVault(payload),
        throwsA(
          isA<AegisImportException>().having(
            (error) => error.code,
            'code',
            AegisErrorCode.passwordRequired,
          ),
        ),
      );
    });

    test('非 Aegis 文件报错', () async {
      await expectLater(
        importAegisVault(utf8Bytes('{"hello":1}')),
        throwsA(isA<AegisImportException>()),
      );
    });
  });

  group('Google 迁移', () {
    test('解析单个 TOTP 账号', () {
      final entry = _protoEntry(
        secret: utf8Bytes('Hello!\u00ff'),
        name: 'alice@example.com',
        issuer: 'Example',
        type: 2,
        digits: 1,
        algorithm: 1,
      );
      final payload = _lengthDelimited(1, entry);
      final link =
          'otpauth-migration://offline?data=${base64Url.encode(payload)}';

      final entries = parseGoogleMigration(link);
      expect(entries, hasLength(1));
      expect(entries.first.issuer, 'Example');
      expect(entries.first.account, 'alice@example.com');
      expect(entries.first.type, OtpType.totp);
      expect(entries.first.digits, 6);
      expect(entries.first.secret, isNotEmpty);
    });

    test('识别协议与拒绝坏链接', () {
      expect(
        isGoogleMigrationLink('otpauth-migration://offline?data=AA'),
        isTrue,
      );
      expect(isGoogleMigrationLink('otpauth://totp/x'), isFalse);
      expect(
        () => parseGoogleMigration('otpauth://totp/x'),
        throwsA(isA<GoogleMigrationException>()),
      );
    });
  });

  group('导入合并', () {
    final now = DateTime.utc(2026, 1, 1);

    VaultItem token(String secret, String title) => VaultItem.tokenItem(
      id: 'id-$secret',
      title: title,
      token: TokenData(secret: TotpSecret(secret: secret)),
      createdAt: now,
      updatedAt: now,
    );

    test('按密钥 + 标题去重', () {
      final existing = VaultData(
        vaultId: 'v',
        createdAt: now,
        items: <VaultItem>[token('JBSWY3DPEHPK3PXP', 'GitHub')],
      );
      final merged = mergeImportedItems(existing, <VaultItem>[
        token('JBSWY3DPEHPK3PXP', 'GitHub'),
        token('KRSXG5CTMVRXEZLU', 'Cloudflare'),
      ]);
      expect(merged.imported, 1);
      expect(merged.skippedDuplicates, 1);
      expect(merged.data.items, hasLength(2));
    });
  });
}

/// 构造一份真实的 Aegis 加密导出：scrypt 派生 → AES-GCM 包 master key →
/// AES-GCM 加密 db，nonce/tag 分别放进 header。
Future<Uint8List> _encryptedAegis({
  required String password,
  required String entriesJson,
}) async {
  const n = 16;
  const r = 8;
  const p = 1;
  final salt = randomBytes(16);
  final masterKey = randomBytes(32);

  final derivator = Scrypt()..init(ScryptParameters(n, r, p, 32, salt));
  final derived = derivator.process(utf8Bytes(password));

  final keyBox = await sealBytes(
    key: Uint8List.fromList(derived),
    plaintext: masterKey,
    aad: const <int>[],
  );
  final dbBox = await sealBytes(
    key: masterKey,
    plaintext: utf8Bytes(entriesJson),
    aad: const <int>[],
  );

  final splitKey = _split(keyBox.cipherText);
  final splitDb = _split(dbBox.cipherText);

  return utf8Bytes(
    jsonEncode(<String, Object?>{
      'version': 1,
      'header': <String, Object?>{
        'slots': <Object?>[
          <String, Object?>{
            'type': 1,
            'uuid': 'slot-1',
            'n': n,
            'r': r,
            'p': p,
            'salt': hexOf(salt),
            'key': hexOf(splitKey.ciphertext),
            'key_params': <String, Object?>{
              'nonce': hexOf(keyBox.nonce),
              'tag': hexOf(splitKey.tag),
            },
          },
        ],
        'params': <String, Object?>{
          'nonce': hexOf(dbBox.nonce),
          'tag': hexOf(splitDb.tag),
        },
      },
      'db': base64Encode(splitDb.ciphertext),
    }),
  );
}

({Uint8List ciphertext, Uint8List tag}) _split(Uint8List combined) {
  final splitAt = combined.length - 16;
  return (
    ciphertext: Uint8List.sublistView(combined, 0, splitAt),
    tag: Uint8List.sublistView(combined, splitAt),
  );
}

/// 构造 Google 迁移里的 OtpParameters 子消息。
Uint8List _protoEntry({
  required Uint8List secret,
  required String name,
  required String issuer,
  required int type,
  required int digits,
  required int algorithm,
  int counter = 0,
}) {
  final out = BytesBuilder();
  out.add(_lengthDelimited(1, secret));
  out.add(_lengthDelimited(2, utf8Bytes(name)));
  out.add(_lengthDelimited(3, utf8Bytes(issuer)));
  out.add(_varintField(4, algorithm));
  out.add(_varintField(5, digits));
  out.add(_varintField(6, type));
  if (counter != 0) out.add(_varintField(7, counter));
  return out.toBytes();
}

Uint8List _lengthDelimited(int field, List<int> payload) {
  final out = BytesBuilder();
  out.add(_varint((field << 3) | 2));
  out.add(_varint(payload.length));
  out.add(payload);
  return out.toBytes();
}

Uint8List _varintField(int field, int value) {
  final out = BytesBuilder();
  out.add(_varint(field << 3));
  out.add(_varint(value));
  return out.toBytes();
}

Uint8List _varint(int value) {
  final out = <int>[];
  var remaining = value;
  while (remaining >= 0x80) {
    out.add((remaining & 0x7F) | 0x80);
    remaining >>= 7;
  }
  out.add(remaining);
  return Uint8List.fromList(out);
}
