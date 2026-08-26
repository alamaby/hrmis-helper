String prepareFailureStatus(String? result) {
  return switch (result) {
    'missing-description' =>
      'Description field not found. Stay on the attendance form and retry.',
    'missing-flag-location' =>
      'Attendance type option not found on the form. Reload and retry.',
    'attendance-error' => 'Attendance form preparation failed.',
    _ => 'Attendance form not ready.',
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
