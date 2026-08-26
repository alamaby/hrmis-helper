import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/core/javascript_result.dart';

void main() {
  group('normalizeJavascriptResult', () {
    test('unwraps a quoted string result', () {
      final result = normalizeJavascriptResult('"attendance-prepared"');

      expect(result, 'attendance-prepared');
    });

    test('leaves an unquoted string untouched', () {
      final result = normalizeJavascriptResult('attendance-prepared');

      expect(result, 'attendance-prepared');
    });

    test('unwraps a quoted boolean-like string', () {
      expect(normalizeJavascriptResult('"true"'), 'true');
    });

    test('converts a quoted number string', () {
      expect(normalizeJavascriptResult('"42"'), '42');
    });

    test('leaves single-character strings untouched', () {
      expect(normalizeJavascriptResult('"'), '"');
    });

    test('unwraps an empty quoted string', () {
      expect(normalizeJavascriptResult('""'), '');
    });

    test('leaves non-string results untouched', () {
      expect(normalizeJavascriptResult(42), 42);
      expect(normalizeJavascriptResult(true), true);
      expect(normalizeJavascriptResult(null), isNull);
    });

    test('leaves malformed quoted strings untouched', () {
      final result = normalizeJavascriptResult('"unclosed');

      expect(result, '"unclosed');
    });

    test('trims whitespace before checking quotes', () {
      final result = normalizeJavascriptResult('  "attendance-prepared"  ');

      expect(result, 'attendance-prepared');
    });
  });
}
