import 'dart:convert';

/// Normalizes WebView JavaScript evaluation results.
///
/// Some Android WebView engines wrap string results in an extra JSON quote
/// layer (`"attendance-prepared"` instead of `attendance-prepared`), which
/// breaks direct Dart string comparisons.
dynamic normalizeJavascriptResult(dynamic result) {
  if (result is! String || result.length < 2) return result;

  final trimmed = result.trim();
  if (!trimmed.startsWith('"') || !trimmed.endsWith('"')) return result;

  try {
    final decoded = jsonDecode(trimmed);
    return decoded is String ? decoded : result;
  } catch (_) {
    return result;
  }
}
