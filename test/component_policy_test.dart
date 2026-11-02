import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> dartFiles(Directory root) {
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);
}

void main() {
  test('禁止重新引入底部单选弹层与分段单选控件', () {
    final files = dartFiles(Directory('lib'));
    final hits = <String>[];

    for (final file in files) {
      final source = file.readAsStringSync();
      final path = file.path.replaceAll('\\', '/');
      if (source.contains('showKcOptionSheet') ||
          source.contains('KcSegmentedControl')) {
        hits.add(path);
        continue;
      }
      if (source.contains('showModalBottomSheet') &&
          path != 'lib/pages/sheets.dart') {
        hits.add(path);
      }
    }

    expect(hits, isEmpty, reason: '单选必须走 KcMenuRow / 锚点菜单');
  });
}
