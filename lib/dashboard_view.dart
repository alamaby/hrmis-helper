import 'package:flutter/material.dart';

enum AttendanceTodayStatus {
  checking,
  recorded,
  notRecorded,
  failed,
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.attendanceStatus,
    required this.automationStatus,
    required this.lateMinutes,
    required this.absenceDays,
    required this.hasRequiredPermissions,
    required this.isRequestingPermissions,
    required this.onRunAttendance,
    required this.onRequestPermissions,
    required this.onOpenAutomation,
    this.selectedTypeLabel,
  });

  final AttendanceTodayStatus attendanceStatus;
  final String automationStatus;
  final int lateMinutes;
  final int absenceDays;
  final bool hasRequiredPermissions;
  final bool isRequestingPermissions;
  final VoidCallback onRunAttendance;
  final VoidCallback onRequestPermissions;
  final VoidCallback onOpenAutomation;

  /// Label of the most recently selected attendance type (WFO/WFH/SPJ),
  /// shown on the action panel so the user can confirm before running.
  final String? selectedTypeLabel;

  bool get _hasWarning => lateMinutes > 0 || absenceDays > 0;

  bool get _canRunAttendance =>
      hasRequiredPermissions &&
      attendanceStatus != AttendanceTodayStatus.recorded;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        DashboardHeader(
          attendanceStatus: attendanceStatus,
          hasWarning: _hasWarning,
        ),
        const SizedBox(height: 16),
        ActionPanel(
          attendanceStatus: attendanceStatus,
          automationStatus: automationStatus,
          hasRequiredPermissions: hasRequiredPermissions,
          isRequestingPermissions: isRequestingPermissions,
          canRunAttendance: _canRunAttendance,
          selectedTypeLabel: selectedTypeLabel,
          onRunAttendance: onRunAttendance,
          onRequestPermissions: onRequestPermissions,
          onOpenAutomation: onOpenAutomation,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                icon: Icons.schedule,
                title: 'Delay',
                value: lateMinutes.toString(),
                unit: 'minutes',
                color: const Color(0xFFB45309),
                backgroundColor: const Color(0xFFFFF7ED),
                isWarning: lateMinutes > 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                icon: Icons.event_busy_outlined,
                title: 'Absence',
                value: absenceDays.toString(),
                unit: 'days',
                color: const Color(0xFFB91C1C),
                backgroundColor: const Color(0xFFFEF2F2),
                isWarning: absenceDays > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StatusTimeline(
          attendanceStatus: attendanceStatus,
          lateMinutes: lateMinutes,
          absenceDays: absenceDays,
        ),
      ],
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.attendanceStatus,
    required this.hasWarning,
  });

  final AttendanceTodayStatus attendanceStatus;
  final bool hasWarning;

  static String statusText(AttendanceTodayStatus status) {
    return switch (status) {
      AttendanceTodayStatus.checking => 'Checking',
      AttendanceTodayStatus.recorded => 'Recorded',
      AttendanceTodayStatus.notRecorded => 'Not recorded',
      AttendanceTodayStatus.failed => 'Needs action',
    };
  }

  static Color statusColor(AttendanceTodayStatus status) {
    return switch (status) {
      AttendanceTodayStatus.checking => const Color(0xFF2563EB),
      AttendanceTodayStatus.recorded => const Color(0xFF047857),
      AttendanceTodayStatus.notRecorded => const Color(0xFFB45309),
      AttendanceTodayStatus.failed => const Color(0xFFB91C1C),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          height: 1.05,
        );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF102A43),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              StatusPill(
                text: statusText(attendanceStatus),
                foregroundColor: statusColor(attendanceStatus),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('HRMIS Helper', style: titleStyle),
          const SizedBox(height: 6),
          Text(
            hasWarning
                ? 'There are attendance items that need your attention.'
                : 'Attendance automation and HRMIS checks are ready.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.surface,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class ActionPanel extends StatelessWidget {
  const ActionPanel({
    super.key,
    required this.attendanceStatus,
    required this.automationStatus,
    required this.hasRequiredPermissions,
    required this.isRequestingPermissions,
    required this.canRunAttendance,
    required this.onRunAttendance,
    required this.onRequestPermissions,
    required this.onOpenAutomation,
    this.selectedTypeLabel,
  });

  final AttendanceTodayStatus attendanceStatus;
  final String automationStatus;
  final bool hasRequiredPermissions;
  final bool isRequestingPermissions;
  final bool canRunAttendance;
  final String? selectedTypeLabel;
  final VoidCallback onRunAttendance;
  final VoidCallback onRequestPermissions;
  final VoidCallback onOpenAutomation;

  @override
  Widget build(BuildContext context) {
    final message = switch (attendanceStatus) {
      AttendanceTodayStatus.recorded =>
        'Attendance has been recorded for today.',
      AttendanceTodayStatus.notRecorded =>
        'Attendance is not confirmed yet. Run the automation again.',
      AttendanceTodayStatus.failed =>
        'Automation needs attention before it can continue.',
      AttendanceTodayStatus.checking => 'Automation is checking HRMIS.',
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, color: Color(0xFF0F766E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            automationStatus,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
          const SizedBox(height: 16),
          if (canRunAttendance && selectedTypeLabel != null) ...[
            Text(
              'Last attendance type: ${selectedTypeLabel!}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
            const SizedBox(height: 8),
          ],
          if (!hasRequiredPermissions)
            FilledButton.icon(
              onPressed: isRequestingPermissions ? null : onRequestPermissions,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                isRequestingPermissions
                    ? 'Requesting permissions'
                    : 'Grant permissions',
              ),
            )
          else if (canRunAttendance)
            FilledButton.icon(
              onPressed: onRunAttendance,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Run attendance'),
            )
          else
            OutlinedButton.icon(
              onPressed: onOpenAutomation,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open automation view'),
            ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    required this.backgroundColor,
    required this.isWarning,
  });

  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final Color color;
  final Color backgroundColor;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 156,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isWarning
                ? color.withValues(alpha: 0.38)
                : const Color(0xFFE5E7EB),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 22),
            Text(
              value,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                    height: 1,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '$title ($unit)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    height: 1.25,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.attendanceStatus,
    required this.lateMinutes,
    required this.absenceDays,
  });

  final AttendanceTodayStatus attendanceStatus;
  final int lateMinutes;
  final int absenceDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today at a Glance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          TimelineRow(
            icon: Icons.login_rounded,
            title: 'Attendance status',
            value: switch (attendanceStatus) {
              AttendanceTodayStatus.recorded => 'Recorded',
              AttendanceTodayStatus.notRecorded => 'Not confirmed',
              AttendanceTodayStatus.failed => 'Needs attention',
              AttendanceTodayStatus.checking => 'Checking',
            },
          ),
          const Divider(height: 22),
          TimelineRow(
            icon: Icons.notifications_active_outlined,
            title: 'Notification rule',
            value: lateMinutes > 0 || absenceDays > 0
                ? 'Warning sent when checks completed'
                : 'No warning required',
          ),
        ],
      ),
    );
  }
}

class TimelineRow extends StatelessWidget {
  const TimelineRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    required this.foregroundColor,
  });

  final String text;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: foregroundColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.36)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
