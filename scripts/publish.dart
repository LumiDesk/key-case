// 发版脚本：dart run scripts/publish.dart patch|minor|major|1.2.3 [--dry-run]
//
// 与 verifin 的分工一致：脚本只做「改版本号 → 格式化 → analyze → test → 提交 → 打标签 →
// 推送」，签名构建与发布由 .github/workflows/release.yml 完成。
// 打标签会触发远端 CI，因此必须由用户明确要求后才能执行。
// 这是命令行脚本，输出就是产品本身，因此豁免 avoid_print。
// ignore_for_file: avoid_print
import 'dart:io';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final positional = args.where((arg) => !arg.startsWith('--')).toList();
  if (positional.isEmpty) {
    stderr.writeln(
      '用法: dart run scripts/publish.dart patch|minor|major|X.Y.Z [--dry-run]',
    );
    exit(64);
  }

  final pubspec = File('pubspec.yaml');
  final content = await pubspec.readAsString();
  final match = RegExp(
    r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (match == null) {
    stderr.writeln('pubspec.yaml 里找不到 version: X.Y.Z+N');
    exit(1);
  }

  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  final patch = int.parse(match.group(3)!);
  final build = int.parse(match.group(4)!);

  final (int, int, int) next;
  switch (positional.first) {
    case 'major':
      next = (major + 1, 0, 0);
    case 'minor':
      next = (major, minor + 1, 0);
    case 'patch':
      next = (major, minor, patch + 1);
    default:
      final parts = positional.first.split('.');
      if (parts.length != 3) {
        stderr.writeln('版本号必须是 patch / minor / major 或 X.Y.Z');
        exit(64);
      }
      next = (int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  final version = '${next.$1}.${next.$2}.${next.$3}';
  final nextBuild = build + 1;
  print(
    '版本: ${match.group(0)!.replaceFirst('version: ', '')} -> $version+$nextBuild',
  );

  if (dryRun) {
    print('--dry-run：跳过写入与提交');
    return;
  }

  await _run(<String>['git', 'status', '--porcelain'], expectCleanOutput: true);

  final updated = content.replaceFirst(
    match.group(0)!,
    'version: $version+$nextBuild',
  );
  await pubspec.writeAsString(updated);

  final appVersion = File('lib/app/app_version.dart');
  await appVersion.writeAsString(
    "const String kAppVersion = '$version';\n"
    'const int kAppBuildNumber = $nextBuild;\n',
  );

  await _run(<String>['dart', 'format', '.']);
  await _run(<String>['flutter', 'analyze']);
  await _run(<String>['flutter', 'test']);
  await _run(<String>[
    'git',
    'add',
    'pubspec.yaml',
    'lib/app/app_version.dart',
  ]);
  await _run(<String>['git', 'commit', '-m', 'chore: release v$version']);
  await _run(<String>['git', 'tag', 'v$version']);
  await _run(<String>['git', 'push', 'origin', 'HEAD']);
  await _run(<String>['git', 'push', 'origin', 'v$version']);
  print('已推送 v$version，CI 会构建签名 APK 并创建预发布。');
}

Future<void> _run(
  List<String> command, {
  bool expectCleanOutput = false,
}) async {
  final result = await Process.run(command.first, command.sublist(1));
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr.writeln('命令失败: ${command.join(' ')}');
    exit(result.exitCode);
  }
  if (expectCleanOutput && (result.stdout as String).trim().isNotEmpty) {
    stderr.writeln('工作区不干净，先提交或清理再发版。');
    exit(1);
  }
}
