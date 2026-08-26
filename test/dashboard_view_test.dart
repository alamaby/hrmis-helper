import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/dashboard_view.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> pumpDashboard(
  WidgetTester tester, {
  AttendanceTodayStatus attendanceStatus = AttendanceTodayStatus.checking,
  String automationStatus = 'Idle',
  int lateMinutes = 0,
  int absenceDays = 0,
  bool hasRequiredPermissions = true,
  bool isRequestingPermissions = false,
  String? selectedTypeLabel,
}) {
  return tester.pumpWidget(
    wrap(
      DashboardView(
        attendanceStatus: attendanceStatus,
        automationStatus: automationStatus,
        lateMinutes: lateMinutes,
        absenceDays: absenceDays,
        hasRequiredPermissions: hasRequiredPermissions,
        isRequestingPermissions: isRequestingPermissions,
        onRunAttendance: () {},
        onRequestPermissions: () {},
        onOpenAutomation: () {},
        selectedTypeLabel: selectedTypeLabel,
      ),
    ),
  );
}

void main() {
  group('DashboardView metrics', () {
    testWidgets('renders delay and absence metric values', (tester) async {
      await pumpDashboard(tester, lateMinutes: 12, absenceDays: 3);

      expect(find.text('12'), findsOneWidget);
      expect(find.text('Delay (minutes)'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Absence (days)'), findsOneWidget);
    });

    testWidgets('shows warning subtitle when metrics are non-zero',
        (tester) async {
      await pumpDashboard(tester, lateMinutes: 5);

      expect(
        find.text('There are attendance items that need your attention.'),
        findsOneWidget,
      );
    });

    testWidgets('shows ready subtitle when metrics are zero', (tester) async {
      await pumpDashboard(tester);

      expect(
        find.text('Attendance automation and HRMIS checks are ready.'),
        findsOneWidget,
      );
    });
  });

  group('ActionPanel button states', () {
    testWidgets('shows Grant permissions when permissions missing',
        (tester) async {
      await pumpDashboard(tester, hasRequiredPermissions: false);

      expect(find.text('Grant permissions'), findsOneWidget);
      expect(find.text('Run attendance'), findsNothing);
    });

    testWidgets('disables grant button while requesting permissions',
        (tester) async {
      await pumpDashboard(
        tester,
        hasRequiredPermissions: false,
        isRequestingPermissions: true,
      );

      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Requesting permissions'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shows Run attendance when permitted and not recorded',
        (tester) async {
      await pumpDashboard(tester);

      expect(find.text('Run attendance'), findsOneWidget);
      expect(find.text('Grant permissions'), findsNothing);
    });

    testWidgets('hides Run attendance once attendance is recorded',
        (tester) async {
      await pumpDashboard(
        tester,
        attendanceStatus: AttendanceTodayStatus.recorded,
      );

      expect(find.text('Run attendance'), findsNothing);
      expect(find.text('Open automation view'), findsOneWidget);
      expect(
        find.text('Attendance has been recorded for today.'),
        findsOneWidget,
      );
    });

    testWidgets('shows checking message while status is checking',
        (tester) async {
      await pumpDashboard(tester);

      expect(find.text('Automation is checking HRMIS.'), findsOneWidget);
    });

    testWidgets('shows last attendance type when provided', (tester) async {
      await pumpDashboard(tester, selectedTypeLabel: 'WFH');

      expect(find.text('Last attendance type: WFH'), findsOneWidget);
    });

    testWidgets('hides last attendance type when not provided', (tester) async {
      await pumpDashboard(tester);

      expect(find.textContaining('Last attendance type'), findsNothing);
    });
  });

  group('StatusTimeline', () {
    testWidgets('reflects recorded attendance status', (tester) async {
      await pumpDashboard(
        tester,
        attendanceStatus: AttendanceTodayStatus.recorded,
      );

      expect(find.text('Recorded'), findsNWidgets(2));
      expect(find.text('No warning required'), findsOneWidget);
    });

    testWidgets('flags notification rule when warnings exist', (tester) async {
      await pumpDashboard(tester, absenceDays: 2);

      expect(
        find.text('Warning sent when checks completed'),
        findsOneWidget,
      );
    });
  });

  group('DashboardHeader.status helpers', () {
    test('maps every status to its label', () {
      expect(DashboardHeader.statusText(AttendanceTodayStatus.checking),
          'Checking');
      expect(DashboardHeader.statusText(AttendanceTodayStatus.recorded),
          'Recorded');
      expect(DashboardHeader.statusText(AttendanceTodayStatus.notRecorded),
          'Not recorded');
      expect(DashboardHeader.statusText(AttendanceTodayStatus.failed),
          'Needs action');
    });
  });
}
