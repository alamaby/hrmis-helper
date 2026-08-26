import 'package:flutter/material.dart';

import 'core/attendance_type.dart';

const Color _primaryBlue = Color(0xFF246BFD);

Future<AttendanceType?> showAttendanceTypePicker(BuildContext context) {
  return showModalBottomSheet<AttendanceType>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const AttendanceTypeSheet(),
  );
}

class AttendanceTypeSheet extends StatelessWidget {
  const AttendanceTypeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select attendance type',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Geolocation is only required for WFO.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final type in AttendanceType.values)
              ListTile(
                key: ValueKey(type),
                leading: Icon(_iconFor(type), color: _primaryBlue),
                title: Text(
                  type.label,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  type.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
                trailing: type.requiresGeolocation
                    ? const Tooltip(
                        message: 'Requires device location',
                        child: Icon(Icons.location_on_outlined, size: 20),
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(type),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AttendanceType type) => switch (type) {
        AttendanceType.wfo => Icons.apartment_rounded,
        AttendanceType.wfh => Icons.home_work_rounded,
        AttendanceType.spj => Icons.receipt_long_rounded,
      };
}
