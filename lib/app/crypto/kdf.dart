/// 口令派生：Argon2id。
///
/// 参数写在容器头里，所以以后调高默认值不影响老库：解锁时永远按头里的参数算。
///
/// 默认值来自本机实测（API 37 模拟器、AOT profile）：64 MiB / 3 轮 / p2 约 0.5 秒，
/// AES-GCM 对百 KB 级正文开销可忽略，因此整个解锁流程不需要原生加密桥。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class KdfParams {
  const KdfParams({
    this.memoryKib = 65536,
    this.iterations = 3,
    this.parallelism = 2,
  });

  /// 内存成本，单位 KiB。
  final int memoryKib;
  final int iterations;
  final int parallelism;

  Map<String, Object?> toJson() => <String, Object?>{
    'algorithm': 'argon2id',
    'memoryKib': memoryKib,
    'iterations': iterations,
    'parallelism': parallelism,
  };

  factory KdfParams.fromJson(Map<String, Object?> json) {
    return KdfParams(
      memoryKib: (json['memoryKib'] as num?)?.toInt() ?? 32768,
      iterations: (json['iterations'] as num?)?.toInt() ?? 3,
      parallelism: (json['parallelism'] as num?)?.toInt() ?? 2,
    );
  }
}

/// Argon2id 派生 32 字节密钥。
///
/// 这是整个解锁流程里最慢的一步，调用方必须放到后台 isolate（见
/// [VaultRepository.unlock]），否则会卡住首帧。
Future<Uint8List> deriveArgon2idKey({
  required String password,
  required Uint8List salt,
  required KdfParams params,
}) async {
  final algorithm = Argon2id(
    parallelism: params.parallelism,
    memory: params.memoryKib,
    iterations: params.iterations,
    hashLength: 32,
  );
  final key = await algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  return Uint8List.fromList(await key.extractBytes());
}
