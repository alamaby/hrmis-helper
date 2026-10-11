import 'package:flutter_test/flutter_test.dart';

import 'package:hrmis_helper/core/attendance_recorded_js.dart';

void main() {
  group('AttendanceFormState', () {
    test('parses known state codes', () {
      expect(
        AttendanceFormState.parse('attendance-recorded'),
        AttendanceFormState.recorded,
      );
      expect(
        AttendanceFormState.parse('attendance-open'),
        AttendanceFormState.open,
      );
    });

    test('falls back to pending for unknown or missing codes', () {
      expect(
        AttendanceFormState.parse('attendance-pending'),
        AttendanceFormState.pending,
      );
      expect(AttendanceFormState.parse('unknown'), AttendanceFormState.pending);
      expect(AttendanceFormState.parse(null), AttendanceFormState.pending);
    });

    test('round-trips through code', () {
      expect(
        AttendanceFormState.parse(AttendanceFormState.recorded.code),
        AttendanceFormState.recorded,
      );
      expect(
        AttendanceFormState.parse(AttendanceFormState.open.code),
        AttendanceFormState.open,
      );
    });
  });

  group('AttendanceFormSignals', () {
    test('splits the JS verdict from its flag payload', () {
      final signals = AttendanceFormSignals.parse(
        'attendance-recorded|signed-in,signed-in-at-07:34',
      );

      expect(signals.state, AttendanceFormState.recorded);
      expect(signals.signedInMessage, isTrue);
      expect(signals.signedInAt, '07:34');
    });

    test('keeps an open verdict even with the sign-in line present', () {
      // Matches the S4-wins-over-S1 rule in the injected JS: an eligible
      // clock-in/out button must never be mistaken for a recorded day.
      final signals = AttendanceFormSignals.parse('attendance-open|signed-in');

      expect(signals.state, AttendanceFormState.open);
      expect(signals.signedInMessage, isTrue);
    });

    test('tracks pending without a sign-in line', () {
      final signals = AttendanceFormSignals.parse('attendance-pending|');

      expect(signals.state, AttendanceFormState.pending);
      expect(signals.signedInMessage, isFalse);
      expect(signals.signedInAt, isNull);
    });

    test('falls back to pending without sign-in info on empty input', () {
      for (final raw in <String?>[null, '', '   ']) {
        final signals = AttendanceFormSignals.parse(raw);
        expect(signals.state, AttendanceFormState.pending);
        expect(signals.signedInMessage, isFalse);
        expect(signals.signedInAt, isNull);
      }
    });
  });

  group('attendanceFormStateJs', () {
    test('reports the recorded verdict before the signed-in flag', () {
      expect(attendanceFormStateJs, contains('attendance-recorded|'));
    });

    test('evaluates the save-button state before the banner', () {
      // S4 must be checked first so "Clock in" overrides the stale
      // server-rendered sign-in line.
      final openIndex = attendanceFormStateJs.indexOf('attendance-open|');
      final recordedIndex =
          attendanceFormStateJs.indexOf('attendance-recorded|');
      expect(openIndex, isNot(-1));
      expect(recordedIndex, isNot(-1));
      expect(openIndex, lessThan(recordedIndex));
    });

    test('never clicks through a hidden save button', () {
      expect(attendanceFormStateJs, contains('isHidden(saveButton)'));
    });
  });
}
