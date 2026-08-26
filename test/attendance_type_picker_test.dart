import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/attendance_type_picker.dart';
import 'package:codex_auto_attend/core/attendance_type.dart';

void main() {
  Future<void> openPicker(
    WidgetTester tester,
    ValueChanged<AttendanceType?> onSelected,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                final picked = await showAttendanceTypePicker(context);
                onSelected(picked);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows all three attendance types', (tester) async {
    await openPicker(tester, (_) {});

    expect(find.byKey(const ValueKey(AttendanceType.wfo)), findsOneWidget);
    expect(find.byKey(const ValueKey(AttendanceType.wfh)), findsOneWidget);
    expect(find.byKey(const ValueKey(AttendanceType.spj)), findsOneWidget);

    expect(find.text('WFO'), findsOneWidget);
    expect(find.text('WFH'), findsOneWidget);
    expect(find.text('SPJ'), findsOneWidget);
  });

  testWidgets('returns the tapped attendance type', (tester) async {
    AttendanceType? selected;
    await openPicker(tester, (picked) => selected = picked);

    await tester.tap(find.byKey(const ValueKey(AttendanceType.wfh)));
    await tester.pumpAndSettle();

    expect(selected, AttendanceType.wfh);
  });

  testWidgets('returns null when dismissed without selection', (tester) async {
    AttendanceType? selected;
    await openPicker(tester, (picked) => selected = picked);

    // Dismiss via the modal barrier.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });

  testWidgets('marks only WFO as requiring geolocation', (tester) async {
    await openPicker(tester, (_) {});

    expect(find.byType(Tooltip), findsOneWidget);
  });
}
