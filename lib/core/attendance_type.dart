/// Attendance types supported by the HRMIS attendance form.
enum AttendanceType {
  /// Work from office — HRMIS radio `#flag_location-WFO` (value 1).
  wfo,

  /// Work from home — HRMIS radio `#flag_location-KEMAH` (value 2),
  /// labelled "Kemah (Kerja di rumah)" on the form.
  wfh,

  /// SPJ (surat perjalanan) — HRMIS radio `#flag_location-SPJ` (value 3).
  spj;

  String get radioId => switch (this) {
        AttendanceType.wfo => 'flag_location-WFO',
        AttendanceType.wfh => 'flag_location-KEMAH',
        AttendanceType.spj => 'flag_location-SPJ',
      };

  String get radioValue => switch (this) {
        AttendanceType.wfo => '1',
        AttendanceType.wfh => '2',
        AttendanceType.spj => '3',
      };

  String get label => switch (this) {
        AttendanceType.wfo => 'WFO',
        AttendanceType.wfh => 'WFH',
        AttendanceType.spj => 'SPJ',
      };

  String get description => switch (this) {
        AttendanceType.wfo => 'Work from office',
        AttendanceType.wfh => 'Kemah (kerja di rumah)',
        AttendanceType.spj => 'Surat perjalanan dinas',
      };

  /// Only WFO is validated against the office geofence by HRMIS.
  bool get requiresGeolocation => this == AttendanceType.wfo;
}
