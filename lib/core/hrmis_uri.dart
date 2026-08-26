class HrmisUri {
  const HrmisUri._();

  static const String host = 'hrmis.neuron.id';
  static const String formPath = '/attendance/dashboard/form';

  static bool isLoginPage(Uri uri) {
    return uri.scheme == 'https' && uri.host == host && uri.path == '/doornew';
  }

  static bool isHomeInspectionPage(Uri uri) => isLoginPage(uri);

  static bool isAttendanceForm(Uri uri) {
    return uri.scheme == 'https' && uri.host == host && uri.path == formPath;
  }

  static bool isHrmisPage(Uri uri) {
    return uri.scheme == 'https' && uri.host == host;
  }

  /// After a successful login HRMIS can land on a home/dashboard page first.
  /// The WebView should be sent directly to the known attendance form route.
  static bool shouldNavigateToAttendanceForm(
    Uri uri, {
    required bool loginInjected,
    required bool formNavigationTriggered,
    required bool attendanceInjected,
  }) {
    if (!isHrmisPage(uri)) return false;
    if (isAttendanceForm(uri)) return false;
    if (formNavigationTriggered || attendanceInjected) return false;

    return loginInjected && (uri.path == '/' || uri.path.contains('dashboard'));
  }
}
