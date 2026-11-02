// 一次性基准入口（不参与正式构建）：
//   flutter run --profile -t tool/bench_main.dart -d emulator-5554
// 结果打进 logcat，用 `adb logcat -s flutter` 查看。
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:keycase/app/crypto/aead.dart';
import 'package:keycase/app/crypto/kdf.dart';
import 'package:keycase/app/crypto/random.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('bench'))),
    ),
  );

  await Future<void>.delayed(const Duration(seconds: 1));

  const salt = '0123456789abcdef';
  for (final params in <KdfParams>[
    const KdfParams(memoryKib: 32768, iterations: 3, parallelism: 2),
    const KdfParams(memoryKib: 65536, iterations: 3, parallelism: 2),
  ]) {
    final watch = Stopwatch()..start();
    await deriveArgon2idKey(
      password: 'benchmark-password',
      salt: Uint8List.fromList(salt.codeUnits),
      params: params,
    );
    watch.stop();
    debugPrint(
      'BENCH argon2id ${params.memoryKib}KiB x${params.iterations} p${params.parallelism}: '
      '${watch.elapsedMilliseconds} ms',
    );
  }

  final key = randomBytes(32);
  for (final size in <int>[1024, 64 * 1024, 4 * 1024 * 1024]) {
    final payload = randomBytes(size);
    final sealWatch = Stopwatch()..start();
    final sealed = await sealBytes(
      key: key,
      plaintext: payload,
      aad: const <int>[],
    );
    sealWatch.stop();
    final openWatch = Stopwatch()..start();
    await openBytes(key: key, sealed: sealed, aad: const <int>[]);
    openWatch.stop();
    debugPrint(
      'BENCH aes-gcm ${(size / 1024).toStringAsFixed(0)} KiB: '
      'seal ${sealWatch.elapsedMilliseconds} ms, open ${openWatch.elapsedMilliseconds} ms',
    );
  }

  debugPrint('BENCH done');
}
