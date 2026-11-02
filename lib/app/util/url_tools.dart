/// 网址工具：只放行 http(s)，其余一律不交给系统浏览器。
library;

final RegExp _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');

/// 把用户输入的网址补全成可打开的绝对地址；非法输入返回 null。
///
/// 规则：已带 scheme 的只接受 http/https；不带 scheme 的按 https 补全，
/// 且必须有主机名。`javascript:`、`intent:`、`file:` 一律拒绝。
String? normalizeUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final hasScheme = _scheme.hasMatch(text);
  final candidate = hasScheme ? text : 'https://$text';
  final uri = Uri.tryParse(candidate);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri.toString();
}

/// 列表里展示用的短地址：去掉 scheme 与末尾斜杠。
String displayUrl(String raw) {
  final normalized = normalizeUrl(raw);
  if (normalized == null) return raw;
  final uri = Uri.parse(normalized);
  final buffer = StringBuffer(uri.host);
  if (uri.path.isNotEmpty && uri.path != '/') buffer.write(uri.path);
  return buffer.toString();
}
