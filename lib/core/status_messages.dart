String prepareFailureStatus(String? result) {
  return switch (result) {
    'already-recorded' =>
      'Attendance form is already recorded. Nothing to submit here.',
    'missing-description' =>
      'Description field not found. Stay on the attendance form and retry.',
    'missing-flag-location' =>
      'Attendance type option not found on the form. Reload and retry.',
    'attendance-error' => 'Attendance form preparation failed.',
    _ => 'Attendance form not ready.',
  };
}

String saveFailureStatus(String? result) {
  return switch (result) {
    'save-button-hidden' =>
      'Attendance save button is hidden — attendance is probably already recorded.',
    'missing-save-button' => 'Attendance save button not found on the form.',
    'attendance-save-error' => 'Attendance save failed on the page.',
    _ => 'Attendance save not submitted.',
  };
}

String geolocationFailureStatus(String? result) {
  return switch (result) {
    'geolocation-missing' =>
      'GPS position not detected. Enable device location and retry.',
    'location-list-missing' =>
      'Location list not loaded. Check connection and retry.',
    'geolocation-check-error' =>
      'Geolocation check failed. Reload the form and retry.',
    _ => 'Form not ready for submission.',
  };
}

/// Status when the sign-in line is present but the form never confirmed its
/// state within the polling budget — deliberately points the user back at
/// "Run attendance" instead of guessing and risking a duplicate submission.
String attendanceUnconfirmedStatus({String? signedInAt}) {
  final at = signedInAt == null ? '' : ' ($signedInAt)';
  return 'Attendance may already be recorded$at but HRMIS did not confirm. '
      'Retry in a moment.';
}
