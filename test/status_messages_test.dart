import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/core/status_messages.dart';

void main() {
  group('prepareFailureStatus', () {
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
}
