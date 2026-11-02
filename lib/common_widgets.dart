/// 通用组件的稳定入口：具体实现按域拆在 app/common_widgets_*.dart。
///
/// 页面只 import 这个文件；新增组件时同步 `docs/design/components.md`。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_theme.dart';
import 'app/icons/aegis_icon.dart';
import 'app/icons/aegis_icon_pack.dart';
import 'app/models/models.dart';
import 'app/otp/otp.dart';
import 'l10n/app_localizations.dart';

part 'app/common_widgets_scaffold.dart';
part 'app/common_widgets_display.dart';
part 'app/common_widgets_forms.dart';
