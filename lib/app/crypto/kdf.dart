/// 口令派生：Argon2id。
///
/// 参数写在容器头里，调整默认值不影响已有库：解锁时按头里的参数计算。
///
/// 默认 64 MiB / 3 轮 / p=2。派生是解锁流程里最慢的一步，调用方必须放到
/// 后台 isolate。
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

  static const int minMemoryKib = 64;
  static const int maxMemoryKib = 256 * 1024;
  static const int maxIterations = 10;
  static const int maxParallelism = 8;

  Map<String, Object?> toJson() => <String, Object?>{
    'algorithm': 'argon2id',
    'memoryKib': memoryKib,
    'iterations': iterations,
    'parallelism': parallelism,
  };

  factory KdfParams.fromJson(Map<String, Object?> json) {
    final memoryKib = (json['memoryKib'] as num?)?.toInt() ?? 65536;
    final iterations = (json['iterations'] as num?)?.toInt() ?? 3;
    final parallelism = (json['parallelism'] as num?)?.toInt() ?? 2;
    if (memoryKib < minMemoryKib ||
        memoryKib > maxMemoryKib ||
        iterations < 1 ||
        iterations > maxIterations ||
        parallelism < 1 ||
        parallelism > maxParallelism) {
      throw const FormatException('KDF 参数超出允许范围');
    }
    return KdfParams(
      memoryKib: memoryKib,
      iterations: iterations,
      parallelism: parallelism,
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
