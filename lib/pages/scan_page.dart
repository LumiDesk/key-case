import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app/app_theme.dart';
import '../app/import/google_migration.dart';
import '../app/import/otpauth_parser.dart';
import '../app/keycase_controller.dart';
import '../app/keycase_scope.dart';
import '../app/models/models.dart';
import '../l10n/app_localizations.dart';
import 'editor_page.dart';

/// 扫码添加令牌。
///
/// 只接受 `otpauth://` 二维码：其他内容不做自动处理，避免把任意 URL 当配置。
/// 识别成功后进入新建令牌页并预填扫码结果，用户确认保存后才写入保险库。
class TokenScanPage extends StatefulWidget {
  const TokenScanPage({super.key, this.initialLink});

  /// 从剪贴板/深链带进来的链接；非空时不打开相机。
  final String? initialLink;

  @override
  State<TokenScanPage> createState() => _TokenScanPageState();
}

class _TokenScanPageState extends State<TokenScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  bool _handling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final link = widget.initialLink;
    if (link != null && link.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consume(link));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _consume(String raw) async {
    if (_handling) return;
    _handling = true;
    final controller = KeyCaseScope.read(context);

    // Google Authenticator 的迁移二维码是另一种协议，直接整体导入。
    if (isGoogleMigrationLink(raw)) {
      final ok = await controller.importGoogleMigrationLink(raw);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = AppLocalizations.of(context).errorMigrationInvalid;
          _handling = false;
        });
        return;
      }
      Navigator.of(context).pop(true);
      return;
    }

    final payload = parseOtpauthUri(raw);
    if (payload == null) {
      setState(() {
        _error = AppLocalizations.of(context).editorSecretInvalid;
        _handling = false;
      });
      return;
    }
    // 扫码只负责识别：把结果当作草稿打开新建令牌页，用户点保存才写入。
    // 用 pushReplacement 换掉相机页，退出编辑页时回到令牌列表。
    final item = payload.toItem(DateTime.now().toUtc());
    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => ItemEditorPage(kind: ItemKind.totp, initialDraft: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.of(context);
    // 锁屏路由盖住本页时不会触发生命周期回调；这里主动停相机，避免锁屏后继续采集。
    if (!controller.state.isUnlocked) {
      unawaited(_controller.stop());
    }
    return Scaffold(
      backgroundColor: kcCanvasDark,
      appBar: AppBar(
        title: Text(l10n.editorScanQr),
        backgroundColor: kcCanvasDark,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  _consume(raw);
                  break;
                }
              }
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.scanCameraUnavailable,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
          const _ScannerFrame(),
          if (_error != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 48,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: kcSemantic(context, kcDanger),
                  borderRadius: BorderRadius.circular(kcRadiusMd),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kcRadiusXl),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 2,
          ),
        ),
      ),
    );
  }
}
