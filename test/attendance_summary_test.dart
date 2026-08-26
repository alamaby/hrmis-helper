import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/core/attendance_summary.dart';

void main() {
  group('parseAttendanceSummary', () {
    test('parses a valid JSON string', () {
      final summary = parseAttendanceSummary(
        '{"lateMinutes": 15, "absenceDays": 2}',
      );

      expect(summary, isNotNull);
      expect(summary!.lateMinutes, 15);
      expect(summary.absenceDays, 2);
    });

    test('parses a double-encoded JSON string from WebView engines', () {
      final summary = parseAttendanceSummary(
        '"{\\"lateMinutes\\": 5, \\"absenceDays\\": 0}"',
      );

      expect(summary, isNotNull);
      expect(summary!.lateMinutes, 5);
      expect(summary.absenceDays, 0);
    });

    test('accepts an already-decoded map', () {
      final summary = parseAttendanceSummary(<String, dynamic>{
        'lateMinutes': 3,
        'absenceDays': 1,
      });

      expect(summary, isNotNull);
      expect(summary!.lateMinutes, 3);
      expect(summary.absenceDays, 1);
    });

    test('defaults missing keys to zero', () {
      final summary = parseAttendanceSummary('{}');

      expect(summary, isNotNull);
      expect(summary!.lateMinutes, 0);
      expect(summary.absenceDays, 0);
    });

    test('truncates double values to integers', () {
      final summary = parseAttendanceSummary(
        '{"lateMinutes": 7.9, "absenceDays": 1.2}',
      );

      expect(summary, isNotNull);
      expect(summary!.lateMinutes, 7);
      expect(summary.absenceDays, 1);
    });

    test('returns null when values are not numeric', () {
      final summary = parseAttendanceSummary(
        '{"lateMinutes": "abc", "absenceDays": null}',
      );

      expect(summary, isNull);
    });

    test('returns null for invalid JSON', () {
      expect(parseAttendanceSummary('not-json'), isNull);
    });

    test('returns null when decoded value is not a map', () {
      expect(parseAttendanceSummary('[1, 2, 3]'), isNull);
    });

    test('returns null for null input', () {
      expect(parseAttendanceSummary(null), isNull);
    });
  });

  group('AttendanceSummary.hasWarning', () {
    test('is false when both values are zero', () {
      const summary = AttendanceSummary(lateMinutes: 0, absenceDays: 0);

      expect(summary.hasWarning, isFalse);
    });

    test('is true when late minutes are positive', () {
      const summary = AttendanceSummary(lateMinutes: 1, absenceDays: 0);

      expect(summary.hasWarning, isTrue);
    });

    test('is true when absence days are positive', () {
      const summary = AttendanceSummary(lateMinutes: 0, absenceDays: 1);

      expect(summary.hasWarning, isTrue);
    });
  });
}
