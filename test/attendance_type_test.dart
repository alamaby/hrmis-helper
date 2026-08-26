import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/core/attendance_prepare_js.dart';
import 'package:codex_auto_attend/core/attendance_type.dart';

void main() {
  group('AttendanceType HRMIS radio mapping', () {
    test('wfo maps to flag_location-WFO with value 1', () {
      expect(AttendanceType.wfo.radioId, 'flag_location-WFO');
      expect(AttendanceType.wfo.radioValue, '1');
    });

    test('wfh maps to the KEMAH radio (Kerja di rumah) with value 2', () {
      expect(AttendanceType.wfh.radioId, 'flag_location-KEMAH');
      expect(AttendanceType.wfh.radioValue, '2');
    });

    test('spj maps to flag_location-SPJ with value 3', () {
      expect(AttendanceType.spj.radioId, 'flag_location-SPJ');
      expect(AttendanceType.spj.radioValue, '3');
    });

    test('labels stay short for status messages', () {
      expect(AttendanceType.wfo.label, 'WFO');
      expect(AttendanceType.wfh.label, 'WFH');
      expect(AttendanceType.spj.label, 'SPJ');
    });
  });

  group('AttendanceType.requiresGeolocation', () {
    test('only WFO requires geolocation', () {
      expect(AttendanceType.wfo.requiresGeolocation, isTrue);
      expect(AttendanceType.wfh.requiresGeolocation, isFalse);
      expect(AttendanceType.spj.requiresGeolocation, isFalse);
    });
  });

  group('prepareAttendanceFormJs', () {
    test('targets the selected type radio by id and value fallback', () {
      final wfoJs = prepareAttendanceFormJs(AttendanceType.wfo);
      expect(wfoJs, contains("getElementById('flag_location-WFO')"));
      expect(wfoJs, contains('[value="1"]'));

      final wfhJs = prepareAttendanceFormJs(AttendanceType.wfh);
      expect(wfhJs, contains("getElementById('flag_location-KEMAH')"));
      expect(wfhJs, contains('[value="2"]'));

      final spjJs = prepareAttendanceFormJs(AttendanceType.spj);
      expect(spjJs, contains("getElementById('flag_location-SPJ')"));
      expect(spjJs, contains('[value="3"]'));
    });

    test('always fills the required description field', () {
      final js = prepareAttendanceFormJs(AttendanceType.spj);

      expect(js, contains("getElementById('start_description')"));
      expect(js, contains(kAttendanceDescriptionText));
      expect(js, contains("'attendance-prepared'"));
      expect(js, contains("'missing-description'"));
    });

    test('no longer hardcodes a single attendance type', () {
      final js = prepareAttendanceFormJs(AttendanceType.wfh);

      expect(js, contains("input[name=\"flag_location\"]"));
      expect(js, isNot(contains('work from office')));
    });

    test('fails loudly when a non-wfo radio is missing', () {
      final js = prepareAttendanceFormJs(AttendanceType.wfh);

      expect(js, contains("'missing-flag-location'"));
      expect(js, contains('if (!typeSelected && true)'));
    });

    test('keeps wfo tolerant to a missing radio (legacy behavior)', () {
      final js = prepareAttendanceFormJs(AttendanceType.wfo);

      expect(js, contains("'missing-flag-location'"));
      expect(js, contains('if (!typeSelected && false)'));
    });
  });
}
