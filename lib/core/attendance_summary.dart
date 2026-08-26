import 'dart:convert';

class AttendanceSummary {
  const AttendanceSummary({
    required this.lateMinutes,
    required this.absenceDays,
  });

  final int lateMinutes;
  final int absenceDays;

  bool get hasWarning => lateMinutes > 0 || absenceDays > 0;
}

AttendanceSummary? parseAttendanceSummary(dynamic result) {
  try {
    dynamic decoded = result;

    if (decoded is String) {
      decoded = jsonDecode(decoded);
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
    }

    if (decoded is! Map<String, dynamic>) return null;

    return AttendanceSummary(
      lateMinutes: (decoded['lateMinutes'] as num?)?.toInt() ?? 0,
      absenceDays: (decoded['absenceDays'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return null;
  }
}
