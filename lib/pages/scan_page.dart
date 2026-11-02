import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app/app_theme.dart';
import '../app/feedback.dart';
import '../app/import/otpauth_parser.dart';
import '../app/keycase_controller.dart';
import '../app/keycase_scope.dart';
import '../l10n/app_localizations.dart';

/// 扫码添加令牌。
///
/// 只接受 `otpauth://` 二维码：其他内容不做自动处理，避免把任意 URL 当配置。
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
    final payload = parseOtpauthUri(raw);
    if (payload == null) {
      setState(() {
        _error = AppLocalizations.of(context).editorSecretInvalid;
        _handling = false;
      });
      return;
    }
    final controller = KeyCaseScope.read(context);
    final now = DateTime.now().toUtc();
    final item = payload
        .toItem(now)
        .copyWith(id: '${now.microsecondsSinceEpoch}');
    await controller.saveItem(item);
    if (!mounted) return;
    KcFeedbackScope.maybeOf(context)
        ?.show(AppLocalizations.of(context).noticeItemSaved);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  error.errorDetails?.message ?? l10n.editorSecretInvalid,
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
