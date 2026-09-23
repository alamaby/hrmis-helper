import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/core/status_messages.dart';

void main() {
  group('prepareFailureStatus', () {
    test('maps already-recorded when the form is settled', () {
      expect(
        prepareFailureStatus('already-recorded'),
        'Attendance form is already recorded. Nothing to submit here.',
      );
    });

    test('maps missing-description', () {
      expect(
        prepareFailureStatus('missing-description'),
        'Description field not found. Stay on the attendance form and retry.',
      );
    });

    test('maps attendance-error', () {
      expect(
        prepareFailureStatus('attendance-error'),
        'Attendance form preparation failed.',
      );
    });

    test('maps missing-flag-location', () {
      expect(
        prepareFailureStatus('missing-flag-location'),
        'Attendance type option not found on the form. Reload and retry.',
      );
    });

    test('falls back for unknown or missing codes', () {
      expect(prepareFailureStatus(null), 'Attendance form not ready.');
      expect(prepareFailureStatus('unknown'), 'Attendance form not ready.');
    });
  });

  group('geolocationFailureStatus', () {
    test('maps geolocation-missing', () {
      expect(
        geolocationFailureStatus('geolocation-missing'),
        'GPS position not detected. Enable device location and retry.',
      );
    });

    test('maps location-list-missing', () {
      expect(
        geolocationFailureStatus('location-list-missing'),
        'Location list not loaded. Check connection and retry.',
      );
    });

    test('maps geolocation-check-error', () {
      expect(
        geolocationFailureStatus('geolocation-check-error'),
        'Geolocation check failed. Reload the form and retry.',
      );
    });

    test('falls back for unknown or missing codes', () {
      expect(
        geolocationFailureStatus(null),
        'Form not ready for submission.',
      );
      expect(
        geolocationFailureStatus('unknown'),
        'Form not ready for submission.',
      );
    });
  });

  group('saveFailureStatus', () {
    test('maps save-button-hidden', () {
      expect(
        saveFailureStatus('save-button-hidden'),
        'Attendance save button is hidden — attendance is probably already recorded.',
      );
    });

    test('maps missing-save-button and attendance-save-error', () {
      expect(
        saveFailureStatus('missing-save-button'),
        'Attendance save button not found on the form.',
      );
      expect(
        saveFailureStatus('attendance-save-error'),
        'Attendance save failed on the page.',
      );
    });

    test('falls back for unknown or missing codes', () {
      expect(saveFailureStatus(null), 'Attendance save not submitted.');
      expect(saveFailureStatus('unknown'), 'Attendance save not submitted.');
    });
  });

  group('attendanceUnconfirmedStatus', () {
    test('includes the sign-in time when known', () {
      expect(
        attendanceUnconfirmedStatus(signedInAt: '07:34'),
        contains('07:34'),
      );
    });

    test('still asks for a retry without a time', () {
      final status = attendanceUnconfirmedStatus();
      expect(status, contains('may already be recorded'));
      expect(status, contains('Retry in a moment.'));
    });
  });
}
