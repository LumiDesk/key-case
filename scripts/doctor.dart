// 环境自检：dart run scripts/doctor.dart
//
// 只读检查，不改动任何工具链。发现缺项时打印建议，由用户决定是否安装。
// 这是命令行脚本，输出就是产品本身，因此豁免 avoid_print。
// ignore_for_file: avoid_print
import 'dart:io';

Future<void> main() async {
  var failed = false;

  final flutter = await _capture(<String>['flutter', '--version']);
  if (flutter == null) {
    print('[x] 找不到 flutter');
    failed = true;
  } else {
    final firstLine = flutter.split('\n').first.trim();
    print('[ok] $firstLine');
    if (!firstLine.contains('3.47.2')) {
      print('    CI 固定 Flutter 3.47.2，本地版本不一致时 analyze 结果可能不同');
    }
  }

  final java = await _capture(<String>['java', '-version']);
  print(java == null ? '[x] 找不到 java' : '[ok] java 可用');

  final androidHome =
      Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'];
  print(
    androidHome == null
        ? '[!] 未设置 ANDROID_HOME（Gradle 仍可依赖 local.properties）'
        : '[ok] ANDROID_HOME=$androidHome',
  );

  final git = await _capture(<String>['git', 'status', '--porcelain']);
  if (git == null) {
    print('[x] 不在 git 仓库里');
    failed = true;
  } else if (git.trim().isNotEmpty) {
    print('[!] 工作区有未提交改动：\n$git');
  } else {
    print('[ok] 工作区干净');
  }

  exit(failed ? 1 : 0);
}

Future<String?> _capture(List<String> command) async {
  try {
    final result = await Process.run(command.first, command.sublist(1));
    if (result.exitCode != 0) return null;
    return '${result.stdout}${result.stderr}';
  } on ProcessException {
    return null;
  }
}
