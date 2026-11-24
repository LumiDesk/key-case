import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../logging/app_logger.dart';
import 'icon_packs.dart';

/// 把内置图标包的许可证登记到 Flutter 的许可证页。
///
/// 三套包的许可证随资源一起打包（见各包目录下的 LICENSE 文件），
/// 设置页「开源许可证」会逐条列出，不需要在代码里抄许可证全文。
void registerIconPackLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final spec in IconPacks.specs) {
      final text = await _loadLicense(spec);
      if (text == null) continue;
      yield LicenseEntryWithLineBreaks(<String>[spec.attribution], text);
    }
  });
}

Future<String?> _loadLicense(IconPackSpec spec) async {
  try {
    return await rootBundle.loadString(spec.licenseAsset);
  } catch (error) {
    // 许可证文件缺失不影响使用，但要在日志里留痕。
    AppLogger.warn('icon pack license missing (${spec.id.name}): $error');
    return null;
  }
}
