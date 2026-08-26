import 'attendance_type.dart';

const String kAttendanceDescriptionText = 'Bismillah, semangat bekerja!';

/// Builds the injected JS that selects the requested attendance type radio
/// and fills the attendance description field on the HRMIS form.
String prepareAttendanceFormJs(AttendanceType type) {
  // WFO stays tolerant to a missing radio (legacy behavior); other types
  // must never silently submit as the form's default (WFO) without GPS.
  final radioRequired = type.requiresGeolocation ? 'false' : 'true';
  return '''
(function () {
  function findDescriptionField() {
    const byId = document.getElementById('start_description');
    if (byId) return byId;

    const formField = document.querySelector(
      '#form-edit-attendance textarea[name="start_description"], #form-edit-attendance textarea'
    );
    if (formField) return formField;

    const byName = Array.from(document.querySelectorAll('textarea')).find(
      (field) => (field.name || '').toLowerCase().includes('description')
    );
    if (byName) return byName;

    for (const field of document.querySelectorAll('textarea')) {
      const placeholder = (field.getAttribute('placeholder') || '').toLowerCase();
      const id = (field.id || '').toLowerCase();
      const name = (field.name || '').toLowerCase();
      if (
        placeholder.includes('ready to work') ||
        placeholder.includes('description') ||
        id.includes('description') ||
        name.includes('description')
      ) {
        return field;
      }

      const labelText = Array.from(field.labels || [])
        .map((label) => (label.textContent || '').trim())
        .join(' ');
      if (/description/i.test(labelText)) return field;
    }

    for (const label of document.querySelectorAll('label')) {
      if (!/description/i.test((label.textContent || '').trim())) continue;

      const forId = label.getAttribute('for');
      if (forId) {
        const linked = document.getElementById(forId);
        if (linked) return linked;
      }

      const container = label.closest(
        '.form-group, .mb-3, .field, .row, .col, div'
      );
      const textarea = container?.querySelector('textarea');
      if (textarea) return textarea;
    }

    const visibleTextarea = Array.from(document.querySelectorAll('textarea')).find(
      (field) => field.offsetParent !== null && !field.disabled
    );
    if (visibleTextarea) return visibleTextarea;

    return null;
  }

  function selectAttendanceType() {
    const byId = document.getElementById('${type.radioId}');
    if (byId) {
      byId.click();
      console.log('[AutoAttend] Attendance type selected:', '${type.radioId}');
      return true;
    }

    const byValue = document.querySelector(
      'input[name="flag_location"][value="${type.radioValue}"]'
    );
    if (byValue) {
      byValue.click();
      console.log('[AutoAttend] Attendance type selected by value:', '${type.radioValue}');
      return true;
    }

    console.log('[AutoAttend] Attendance type radio not found; using form default.');
    return false;
  }

  try {
    const typeSelected = selectAttendanceType();
    if (!typeSelected && $radioRequired) {
      console.log('[AutoAttend] Required attendance type radio missing.');
      return 'missing-flag-location';
    }

    const description = findDescriptionField();
    if (!description) {
      console.log('[AutoAttend] Description field not found.');
      return 'missing-description';
    }

    description.value = '$kAttendanceDescriptionText';
    description.dispatchEvent(new Event('input', { bubbles: true }));
    description.dispatchEvent(new Event('change', { bubbles: true }));

    return 'attendance-prepared';
  } catch (error) {
    console.log('[AutoAttend] Attendance preparation failed:', error);
    return 'attendance-error';
  }
})();
''';
}
