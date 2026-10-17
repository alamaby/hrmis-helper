/// Detects the current state of the HRMIS attendance form so repeated runs
/// can short-circuit before touching a form that is already recorded.
///
/// HRMIS renders the "You are signed in today on HH:mm" line server-side (it is
/// in the initial HTML), then rewrites the form asynchronously via
/// `POST /attendance/attendance/checkAttendance`. Both moments matter:
///
/// | Code | Signal | Available |
/// | ---- | ------ | --------- |
/// | S1 | `p.msgAttendance` matches "you are signed in today on" | initial HTML |
/// | S2 | recorded banner / `.msgAttendance.text-success` | after AJAX |
/// | S3 | description disabled + save button hidden + radios disabled | after AJAX |
/// | S4 | save button visible with "Clock in"/"Clock out" label | after AJAX, canAttend |
///
/// S1 alone is deliberately not enough to declare the form recorded: it proves
/// HRMIS knows about today's attendance, but the authoritative rewrite may not
/// have landed yet. Only S2 or S3 confirm it.
enum AttendanceFormState {
  /// Attendance is already recorded — nothing left to submit.
  recorded,

  /// The form is ready to accept attendance today.
  open,

  /// No decisive signal yet; the checkAttendance request is probably still
  /// in flight.
  pending;

  static AttendanceFormState parse(String? raw) {
    switch (raw) {
      case 'attendance-recorded':
        return AttendanceFormState.recorded;
      case 'attendance-open':
        return AttendanceFormState.open;
      default:
        return AttendanceFormState.pending;
    }
  }

  String get code => switch (this) {
        AttendanceFormState.recorded => 'attendance-recorded',
        AttendanceFormState.open => 'attendance-open',
        AttendanceFormState.pending => 'attendance-pending',
      };
}

/// Raw flags collected by the injected JS, kept separate from the verdict so
/// the "S1 seen but never confirmed" case can be reasoned about in Dart.
class AttendanceFormSignals {
  const AttendanceFormSignals({
    required this.state,
    required this.signedInMessage,
    this.signedInAt,
  });

  factory AttendanceFormSignals.parse(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const AttendanceFormSignals(
        state: AttendanceFormState.pending,
        signedInMessage: false,
      );
    }

    // The injected JS reports `<state>|<flags>` in one string; split off the
    // verdict before matching so flag payloads never break the comparison.
    final stateCode = trimmed.split('|').first.trim();
    return AttendanceFormSignals(
      state: AttendanceFormState.parse(stateCode),
      signedInMessage: trimmed.contains('signed-in'),
      signedInAt: _extractSignedInAt(trimmed),
    );
  }

  final AttendanceFormState state;

  /// True when the server-rendered "You are signed in today on HH:mm" line is
  /// present (S1).
  final bool signedInMessage;

  /// The `HH:mm` part reported by HRMIS, when available.
  final String? signedInAt;

  // ⚡ Bolt: Cache RegExp compilation to prevent redundant allocations during polling loop.
  static final _signedInAtPattern = RegExp(r'signed-in-at-(\d{1,2}:\d{2})');

  static String? _extractSignedInAt(String raw) {
    final match = _signedInAtPattern.firstMatch(raw);
    return match?.group(1);
  }
}

/// Polling budget for the state check before the caller falls back to its
/// default branch. Ten 1-second attempts are enough for checkAttendance to
/// land on a normal connection while staying fast on re-runs.
const int attendanceFormStateMaxAttempts = 10;

/// Injected JS that reports the attendance form state as
/// `<state>|<flags>` so Dart can read both the verdict and the raw signals
/// from a single evaluation.
///
/// Evaluation order matters: [AttendanceFormState.open] wins over the
/// server-rendered sign-in line so a shift that still allows attendance (or
/// becomes eligible for clock-out) is never mistaken for a recorded day.
const String attendanceFormStateJs = '''
(function () {
  function isHidden(element) {
    if (!element) return true;
    if (element.disabled) return true;
    const style = window.getComputedStyle(element);
    return (
      style.display === 'none' ||
      style.visibility === 'hidden' ||
      element.offsetParent === null
    );
  }

  try {
    const flags = [];

    // S1 — server-rendered sign-in line (available before any AJAX).
    const signInLine = document.querySelector('p.msgAttendance, .msgAttendance');
    const signInText = signInLine ? (signInLine.textContent || '').trim() : '';
    const signedIn = /you are signed in today on/i.test(signInText);
    if (signedIn) {
      flags.push('signed-in');
      const at = signInText.match(/(\\d{1,2}:\\d{2})/);
      if (at) flags.push('signed-in-at-' + at[1]);
    }

    // S4 — HRMIS labels the save button "Clock in"/"Clock out" only when
    // checkAttendance answered canAttend = true.
    const saveButton = document.getElementById('attendance-saveButton');
    const saveLabel = document.getElementById('attendance-saveButton-text');
    const saveLabelText = saveLabel ? (saveLabel.textContent || '').trim() : '';
    const canAttend =
      !isHidden(saveButton) && /clock (in|out)/i.test(saveLabelText);

    if (canAttend) return 'attendance-open|' + flags.join(',');

    // S2 — recorded banner injected by checkAttendance.
    const messages = Array.from(
      document.querySelectorAll(
        '.messages-group strong, .messages-group .messages, .messages-group span'
      )
    ).map((element) => (element.textContent || '').trim().toLowerCase());

    const recordedBanner = messages.some(
      (message) =>
        message.includes('attendance has been recorded') ||
        message.includes('has been recorded at')
    );

    const successSignIn =
      signInLine !== null &&
      signInLine.classList.contains('text-success') &&
      signedIn;

    // S3 — structural state after the form was disabled server-side.
    const description = document.querySelector(
      '#form-edit-attendance textarea[name="start_description"], textarea[name="start_description"]'
    );
    const radios = Array.from(
      document.querySelectorAll('.radio-flag-location')
    );
    const descriptionDisabled = description !== null && description.disabled;
    const radiosDisabled =
      radios.length > 0 && radios.every((radio) => radio.disabled);

    const recorded =
      recordedBanner ||
      successSignIn ||
      (descriptionDisabled && isHidden(saveButton)) ||
      (radiosDisabled && isHidden(saveButton));

    if (recorded) return 'attendance-recorded|' + flags.join(',');
    return 'attendance-pending|' + flags.join(',');
  } catch (error) {
    console.log('[AutoAttend] Attendance state check failed:', error);
    return 'attendance-pending|';
  }
})();
''';
