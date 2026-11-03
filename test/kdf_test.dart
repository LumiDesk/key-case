import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/crypto/kdf.dart';

void main() {
  group('KdfParams.fromJson', () {
    test('接受默认与测试参数', () {
      final defaults = KdfParams.fromJson(<String, Object?>{});
      expect(defaults.memoryKib, 65536);
      expect(defaults.iterations, 3);
      expect(defaults.parallelism, 2);

      final testParams = KdfParams.fromJson(<String, Object?>{
        'memoryKib': 64,
        'iterations': 1,
        'parallelism': 1,
      });
      expect(testParams.memoryKib, 64);
    });

    test('拒绝超限参数', () {
      for (final json in <Map<String, Object?>>[
        <String, Object?>{'memoryKib': KdfParams.maxMemoryKib + 1},
        <String, Object?>{'memoryKib': 0},
        <String, Object?>{'iterations': KdfParams.maxIterations + 1},
        <String, Object?>{'iterations': 0},
        <String, Object?>{'parallelism': KdfParams.maxParallelism + 1},
        <String, Object?>{'parallelism': 0},
      ]) {
        expect(
          () => KdfParams.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });
}
