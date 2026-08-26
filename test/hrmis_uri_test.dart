import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/core/hrmis_uri.dart';

Uri uriOf(String url) => Uri.parse(url);

void main() {
  group('HrmisUri.isLoginPage', () {
    test('returns true for the HRMIS login route', () {
      final result = HrmisUri.isLoginPage(
        uriOf('https://hrmis.neuron.id/doornew'),
      );

      expect(result, isTrue);
    });

    test('returns true when the login route carries query parameters', () {
      final result = HrmisUri.isLoginPage(
        uriOf('https://hrmis.neuron.id/doornew?redirect=/home'),
      );

      expect(result, isTrue);
    });

    test('returns false for other hosts', () {
      final result = HrmisUri.isLoginPage(uriOf('https://example.com/doornew'));

      expect(result, isFalse);
    });

    test('returns false for non-https schemes', () {
      final result =
          HrmisUri.isLoginPage(uriOf('http://hrmis.neuron.id/doornew'));

      expect(result, isFalse);
    });

    test('returns false for other paths on the same host', () {
      final result = HrmisUri.isLoginPage(
        uriOf('https://hrmis.neuron.id/attendance/dashboard/form'),
      );

      expect(result, isFalse);
    });
  });

  group('HrmisUri.isHomeInspectionPage', () {
    test('matches the login page because inspection reuses it', () {
      final result = HrmisUri.isHomeInspectionPage(
        uriOf('https://hrmis.neuron.id/doornew'),
      );

      expect(result, isTrue);
    });
  });

  group('HrmisUri.isAttendanceForm', () {
    test('returns true for the attendance form route', () {
      final result = HrmisUri.isAttendanceForm(
        uriOf('https://hrmis.neuron.id/attendance/dashboard/form'),
      );

      expect(result, isTrue);
    });

    test('returns false for a different path', () {
      final result = HrmisUri.isAttendanceForm(
        uriOf('https://hrmis.neuron.id/attendance/dashboard/summary'),
      );

      expect(result, isFalse);
    });
  });

  group('HrmisUri.isHrmisPage', () {
    test('returns true for any https path on the HRMIS host', () {
      expect(
        HrmisUri.isHrmisPage(uriOf('https://hrmis.neuron.id/anything')),
        isTrue,
      );
      expect(HrmisUri.isHrmisPage(uriOf('https://hrmis.neuron.id/')), isTrue);
    });

    test('returns false for other hosts and schemes', () {
      expect(HrmisUri.isHrmisPage(uriOf('https://example.com/')), isFalse);
      expect(HrmisUri.isHrmisPage(uriOf('http://hrmis.neuron.id/')), isFalse);
    });
  });

  group('HrmisUri.shouldNavigateToAttendanceForm', () {
    final home = uriOf('https://hrmis.neuron.id/');
    final dashboard = uriOf('https://hrmis.neuron.id/doornew_dashboard');
    final form = uriOf('https://hrmis.neuron.id/attendance/dashboard/form');
    final external = uriOf('https://example.com/');

    test('navigates after login lands on root path', () {
      final result = HrmisUri.shouldNavigateToAttendanceForm(
        home,
        loginInjected: true,
        formNavigationTriggered: false,
        attendanceInjected: false,
      );

      expect(result, isTrue);
    });

    test('navigates after login lands on a dashboard path', () {
      final result = HrmisUri.shouldNavigateToAttendanceForm(
        dashboard,
        loginInjected: true,
        formNavigationTriggered: false,
        attendanceInjected: false,
      );

      expect(result, isTrue);
    });

    test('does not navigate before login injection happened', () {
      final result = HrmisUri.shouldNavigateToAttendanceForm(
        home,
        loginInjected: false,
        formNavigationTriggered: false,
        attendanceInjected: false,
      );

      expect(result, isFalse);
    });

    test('does not navigate twice once form navigation was triggered', () {
      final result = HrmisUri.shouldNavigateToAttendanceForm(
        home,
        loginInjected: true,
        formNavigationTriggered: true,
        attendanceInjected: false,
      );

      expect(result, isFalse);
    });

    test('does not navigate once attendance has been injected', () {
      final result = HrmisUri.shouldNavigateToAttendanceForm(
        home,
        loginInjected: true,
        formNavigationTriggered: false,
        attendanceInjected: true,
      );

      expect(result, isFalse);
    });

    test('does not navigate when already on the attendance form', () {
      final result = HrmisUri.shouldNavigateToAttendanceForm(
        form,
        loginInjected: true,
        formNavigationTriggered: false,
        attendanceInjected: false,
      );

      expect(result, isFalse);
    });

    test('does not navigate for external pages', () {
      final result = HrmisUri.shouldNavigateToAttendanceForm(
        external,
        loginInjected: true,
        formNavigationTriggered: false,
        attendanceInjected: false,
      );

      expect(result, isFalse);
    });
  });
}
