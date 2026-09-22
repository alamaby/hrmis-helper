import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/dashboard_view.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('Startup gating — Dashboard integration', () {
    // The idle-gating change in main.dart sets _status = 'Choose Run
    // attendance to start.' when permissions are granted but automation has
    // not yet been requested. DashboardView simply reflects whatever string
    // it receives via automationStatus, so we validate that contract here.

    testWidgets('shows "Choose Run" status when idle', (tester) async {
      await tester.pumpWidget(
        wrap(
          DashboardView(
            attendanceStatus: AttendanceTodayStatus.checking,
            automationStatus: 'Choose Run attendance to start.',
            lateMinutes: 0,
            absenceDays: 0,
            hasRequiredPermissions: true,
            isRequestingPermissions: false,
            onRunAttendance: () {},
            onRequestPermissions: () {},
            onOpenAutomation: () {},
          ),
        ),
      );

      expect(
        find.text('Choose Run attendance to start.'),
        findsOneWidget,
      );
      expect(find.text('Run attendance'), findsOneWidget);
    });

    testWidgets('shows Run button while checking and idle', (tester) async {
      await tester.pumpWidget(
        wrap(
          DashboardView(
            attendanceStatus: AttendanceTodayStatus.checking,
            automationStatus: 'Automation is idle.',
            lateMinutes: 0,
            absenceDays: 0,
            hasRequiredPermissions: true,
            isRequestingPermissions: false,
            onRunAttendance: () {},
            onRequestPermissions: () {},
            onOpenAutomation: () {},
          ),
        ),
      );

      expect(find.text('Run attendance'), findsOneWidget);
    });

    testWidgets('switches to Open automation view after recorded',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          DashboardView(
            attendanceStatus: AttendanceTodayStatus.recorded,
            automationStatus: 'Attendance already recorded.',
            lateMinutes: 0,
            absenceDays: 0,
            hasRequiredPermissions: true,
            isRequestingPermissions: false,
            onRunAttendance: () {},
            onRequestPermissions: () {},
            onOpenAutomation: () {},
          ),
        ),
      );

      expect(find.text('Run attendance'), findsNothing);
      expect(find.text('Open automation view'), findsOneWidget);
    });
  });
}
