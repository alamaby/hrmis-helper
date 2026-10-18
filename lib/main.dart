import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'attendance_type_picker.dart';
import 'config.dart';
import 'core/app_logger.dart';
import 'core/attendance_descriptions.dart';
import 'core/attendance_prepare_js.dart';
import 'core/attendance_recorded_js.dart';
import 'core/attendance_summary.dart';
import 'core/attendance_type.dart';
import 'core/hrmis_uri.dart';
import 'core/javascript_result.dart';
import 'core/status_messages.dart';
import 'credential_screen.dart';
import 'dashboard_view.dart';
import 'notification_service.dart';

const _submitAttendanceFormJs = '''
(function () {
  function findSaveButton() {
    const byId = document.getElementById('attendance-saveButton');
    if (byId) return byId;

    const buttons = Array.from(
      document.querySelectorAll(
        'button, input[type="submit"], input[type="button"], a.btn, [role="button"]'
      )
    );

    return (
      buttons.find((element) => {
        const text = (element.textContent || element.value || '')
          .trim()
          .toLowerCase();
        const id = (element.id || '').toLowerCase();
        return (
          id.includes('save') ||
          id.includes('attendance') ||
          text.includes('save') ||
          text.includes('submit') ||
          text.includes('entrance') ||
          text.includes('clock in') ||
          text.includes('check in')
        );
      }) || null
    );
  }

  try {
    const saveButton = findSaveButton();
    if (!saveButton) {
      console.log('[AutoAttend] Save button not found.');
      return 'missing-save-button';
    }

    // #attendance-saveButton is an <a> element, so .click() still works when
    // HRMIS hides it after a recorded attendance. Never submit through a
    // hidden/disabled button — that would turn a re-run into a clock-out.
    const style = window.getComputedStyle(saveButton);
    const hidden =
      saveButton.disabled ||
      style.display === 'none' ||
      style.visibility === 'hidden' ||
      saveButton.offsetParent === null;
    if (hidden) {
      console.log('[AutoAttend] Save button hidden — nothing to submit.');
      return 'save-button-hidden';
    }

    saveButton.scrollIntoView({ behavior: 'instant', block: 'center' });
    console.log('[AutoAttend] Clicking attendance save button.');
    saveButton.click();
    return 'attendance-save-submitted';
  } catch (error) {
    console.log('[AutoAttend] Attendance save failed:', error);
    return 'attendance-save-error';
  }
})();
''';

const _checkGeolocationReadyJs = '''
(function () {
  try {
    const lat = document.getElementById('latitude');
    const lng = document.getElementById('longitude');
    const locList = document.getElementById('location-list');

    const latValue = lat ? parseFloat(lat.value) : NaN;
    const lngValue = lng ? parseFloat(lng.value) : NaN;

    if (!Number.isFinite(latValue) || !Number.isFinite(lngValue)) {
      return 'geolocation-missing';
    }
    if (latValue === 0 || lngValue === 0) {
      return 'geolocation-missing';
    }
    // location-list lives inside #wfoOnly and is populated async via
    // getLocation() + AJAX. Image 3 shows map ready while list still empty,
    // so treat empty list as warning only when lat/lng already ready.
    if (locList && locList.options && locList.options.length > 0 && !locList.value) {
      console.log('[AutoAttend] location-list empty despite having options');
      return 'location-list-missing';
    }
    if (!locList) {
      console.log('[AutoAttend] location-list element missing — continuing as ready');
    }

    return 'geolocation-ready';
  } catch (error) {
    console.log('[AutoAttend] Geolocation check failed:', error);
    return 'geolocation-check-error';
  }
})();
''';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.load();
  await NotificationService.initialize();
  runApp(const AutoAttendApp());
}

class AutoAttendApp extends StatelessWidget {
  const AutoAttendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HRMIS Helper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF246BFD)),
        useMaterial3: true,
      ),
      home: const AttendanceAutomationPage(),
    );
  }
}

class AttendanceAutomationPage extends StatefulWidget {
  const AttendanceAutomationPage({super.key});

  @override
  State<AttendanceAutomationPage> createState() =>
      _AttendanceAutomationPageState();
}

class _AttendanceAutomationPageState extends State<AttendanceAutomationPage>
    with WidgetsBindingObserver {
  static final Uri _loginUri = Uri.parse('https://hrmis.neuron.id/doornew');
  static final Uri _formUri = Uri.parse(
    'https://hrmis.neuron.id/attendance/dashboard/form',
  );
  static final Uri _homeUri = Uri.parse('https://hrmis.neuron.id/doornew');

  InAppWebViewController? _webViewController;
  AttendanceType _selectedAttendanceType = AttendanceType.wfo;
  int _selectedTabIndex = 0;
  String _status = 'Checking permissions...';
  AttendanceTodayStatus _attendanceTodayStatus = AttendanceTodayStatus.checking;
  int _lateMinutes = 0;
  int _absenceDays = 0;
  bool _hasRequiredPermissions = false;
  bool _loginInjected = false;
  bool _loginInjectionInProgress = false;
  bool _formNavigationTriggered = false;
  bool _attendanceInjected = false;
  bool _attendanceInjectionInProgress = false;
  bool _homeInspectionRequested = false;
  bool _homeInspectionInProgress = false;
  bool _homeInspectionCompleted = false;
  bool _isRequestingPermissions = false;
  // Idle until explicit Run — prevents silent WFO auto-run.
  bool _automationRequested = false;
  // Dedupes the onLoadStop + onUpdateVisitedHistory double-fire for the same
  // form/navigation URL.
  String? _lastHandledUrl;
  DateTime? _lastHandledAt;

  final InAppWebViewSettings _settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    // 🛡️ Sentinel: Security lock-down - Disable cross-origin file access
    allowUniversalAccessFromFileURLs: false,
    allowFileAccessFromFileURLs: false,
    // 🛡️ Sentinel: Security lock-down - Enable Safe Browsing
    safeBrowsingEnabled: true,
    geolocationEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    // 🛡️ Sentinel: Security lock-down - Block mixed content to prevent MITM attacks
    mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
    mediaPlaybackRequiresUserGesture: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'hrmis_automation',
        channelName: 'HRMIS Automation',
        channelDescription: 'Keeps the app alive while HRMIS attendance runs.',
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    FlutterForegroundTask.setTaskHandler(_HrmisKeepAliveTaskHandler());
    _checkPermissions();
    if (!Config.hasCredentials) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCredentialScreen();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseKeepAlive();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _attendanceInjectionInProgress) {
      _updateStatus('Paused — return to app to continue.');
      log('[AutoAttend] Paused during injection');
    } else if (state == AppLifecycleState.resumed &&
        _attendanceInjectionInProgress) {
      _updateStatus('Resumed — checking HRMIS...');
      log('[AutoAttend] Resumed during injection');
    }
  }

  Future<void> _releaseKeepAlive() async {
    try {
      WakelockPlus.disable();
    } catch (e) {
      log('[AutoAttend] Wakelock disable error: $e');
    }
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      log('[AutoAttend] Foreground service stop error: $e');
    }
  }

  Future<void> _checkPermissions() async {
    final locationWhenInUseGranted =
        await Permission.locationWhenInUse.isGranted;
    final locationGranted =
        locationWhenInUseGranted || await Permission.location.isGranted;
    final cameraGranted = await Permission.camera.isGranted;

    if (!mounted) return;
    setState(() {
      _hasRequiredPermissions = locationGranted && cameraGranted;
      _status = _hasRequiredPermissions
          ? 'Choose Run attendance to start.'
          : 'Location and camera permissions are required.';
    });
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isRequestingPermissions = true;
      _status = 'Requesting permissions...';
    });

    final results = await [
      Permission.locationWhenInUse,
      Permission.camera,
    ].request();

    final locationGranted =
        results[Permission.locationWhenInUse]?.isGranted ?? false;
    final cameraGranted = results[Permission.camera]?.isGranted ?? false;

    if (!mounted) return;
    setState(() {
      _isRequestingPermissions = false;
      _hasRequiredPermissions = locationGranted && cameraGranted;
      _status = _hasRequiredPermissions
          ? 'Choose Run attendance to start.'
          : 'Please grant location and camera permissions to continue.';
    });
  }

  Future<void> _openCredentialScreen() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CredentialScreen()),
    );
    if (saved == true && mounted) {
      await Config.load();
      setState(() {});
      // Opsi B: tawarkan picker segera setelah kredensial tersimpan,
      // bukan auto-run WFO silent.
      await _onRunAttendancePressed();
    }
  }

  Future<void> _handleLoadStop(WebUri? webUri) async {
    if (webUri == null) return;

    final uri = Uri.tryParse(webUri.toString());
    if (uri == null) return;

    final url = uri.toString();
    log('[WebView] Load stopped: $url');

    if (!_automationRequested) {
      log('[AutoAttend] Idle — automation not requested yet');
      return;
    }

    // onUpdateVisitedHistory fires for the same navigation as onLoadStop; a
    // second call within 1.5s for the same URL is the same event, not a new
    // page. Swallowing it avoids double injection races that can overwrite a
    // recorded status with a stale follow-up.
    final now = DateTime.now();
    if (_lastHandledUrl == url &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(milliseconds: 1500)) {
      log('[AutoAttend] Deduplicated load-stop for $url');
      return;
    }
    _lastHandledUrl = url;
    _lastHandledAt = now;

    if (HrmisUri.isHomeInspectionPage(uri) &&
        _homeInspectionRequested &&
        !_homeInspectionInProgress &&
        !_homeInspectionCompleted) {
      await _inspectHomeAttendanceSummary();
      return;
    }

    if (HrmisUri.isLoginPage(uri) &&
        !_loginInjected &&
        !_loginInjectionInProgress) {
      await _injectLogin();
      return;
    }

    if (HrmisUri.isAttendanceForm(uri) &&
        !_attendanceInjected &&
        !_attendanceInjectionInProgress) {
      await _injectAttendanceForm();
      return;
    }

    if (HrmisUri.shouldNavigateToAttendanceForm(
      uri,
      loginInjected: _loginInjected,
      formNavigationTriggered: _formNavigationTriggered,
      attendanceInjected: _attendanceInjected,
    )) {
      await _navigateToAttendanceForm(uri);
    }
  }

  Future<void> _navigateToAttendanceForm(Uri currentUri) async {
    _formNavigationTriggered = true;
    _updateStatus('Opening attendance form...');
    log('[AutoAttend] Redirecting from $currentUri to $_formUri');

    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_formUri.toString())),
    );
  }

  Future<void> _onRunAttendancePressed([BuildContext? sheetContext]) async {
    final ctx = sheetContext ?? context;
    final type = await showAttendanceTypePicker(ctx);
    log('[Picker] result=$type');
    if (type == null || !mounted) return;

    setState(() => _selectedAttendanceType = type);
    _automationRequested = true;
    await _runAttendanceAutomation();
  }

  Future<void> _runAttendanceAutomation() async {
    _loginInjected = false;
    _loginInjectionInProgress = false;
    _formNavigationTriggered = false;
    _attendanceInjected = false;
    _attendanceInjectionInProgress = false;
    _homeInspectionRequested = false;
    _homeInspectionInProgress = false;
    _homeInspectionCompleted = false;
    _lastHandledUrl = null;
    _lastHandledAt = null;
    _attendanceTodayStatus = AttendanceTodayStatus.checking;

    setState(() {
      _selectedTabIndex = 1;
      _status = _hasRequiredPermissions
          ? 'Opening HRMIS...'
          : 'Location and camera permissions are required.';
    });

    if (!_hasRequiredPermissions) return;

    // On first Run the WebView is created by _buildAutomationView after this
    // setState, so rely on initialUrlRequest for the very first load. If the
    // controller already exists (e.g. second Run), navigate explicitly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_webViewController == null) return;
      _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_loginUri.toString())),
      );
    });
  }

  Future<void> _navigateToHomeForInspection() async {
    _homeInspectionRequested = true;
    _homeInspectionCompleted = false;
    _updateStatus('Opening HRMIS home...');
    await _releaseKeepAlive();

    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_homeUri.toString())),
    );
  }

  Future<void> _injectLogin() async {
    if (!Config.hasCredentials) {
      _attendanceTodayStatus = AttendanceTodayStatus.failed;
      _updateStatus('No HRMIS credentials stored. Open settings to configure.');
      return;
    }

    _loginInjectionInProgress = true;

    _updateStatus('Checking existing session...');
    await Future<void>.delayed(const Duration(seconds: 1));
    if (await _hasLoggedInProfile()) {
      _loginInjected = true;
      _loginInjectionInProgress = false;
      _updateStatus('Session active. Opening attendance form...');
      await _navigateToAttendanceForm(_loginUri);
      return;
    }

    _updateStatus('Waiting login form (15s)...');
    await Future<void>.delayed(const Duration(seconds: 15));

    final currentUri = await _currentUri();
    if (currentUri == null || !HrmisUri.isLoginPage(currentUri)) {
      _loginInjectionInProgress = false;
      log('[AutoAttend] Login injection skipped. Current URL: $currentUri');
      return;
    }

    if (await _hasLoggedInProfile()) {
      _loginInjected = true;
      _loginInjectionInProgress = false;
      _updateStatus('Session active. Opening attendance form...');
      await _navigateToAttendanceForm(currentUri);
      return;
    }

    for (var attempt = 1; attempt <= 3; attempt += 1) {
      if (!mounted || _loginInjected) break;

      _updateStatus('Logging in... ($attempt/3)');
      final result = await _evaluateJavascript('''
      (function () {
        try {
          const username = ${jsonEncode(Config.username)};
          const password = ${jsonEncode(Config.password)};
          const codeInput = document.getElementById('code');
          const passwordInput = document.getElementById('password');
          const loginButton = document.getElementById('loginBtn');

          if (!codeInput || !passwordInput || !loginButton) {
            console.log('[AutoAttend] Login elements not found.');
            return 'missing-login-elements';
          }

          codeInput.value = username;
          codeInput.dispatchEvent(new Event('input', { bubbles: true }));
          codeInput.dispatchEvent(new Event('change', { bubbles: true }));

          passwordInput.value = password;
          passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
          passwordInput.dispatchEvent(new Event('change', { bubbles: true }));

          console.log('[AutoAttend] Login form filled. Clicking login.');
          loginButton.click();
          return 'login-submitted';
        } catch (error) {
          console.log('[AutoAttend] Login injection failed:', error);
          return 'login-error';
        }
      })();
    ''');

      if (result == 'login-submitted') {
        _loginInjected = true;
        _updateStatus('Login submitted, waiting for HRMIS...');
        break;
      }

      if (await _hasLoggedInProfile()) {
        _loginInjected = true;
        _updateStatus('Session active. Opening attendance form...');
        await _navigateToAttendanceForm(currentUri);
        break;
      }

      log('[AutoAttend] Login attempt $attempt result: $result');
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    _loginInjectionInProgress = false;

    if (!_loginInjected && mounted) {
      _attendanceTodayStatus = AttendanceTodayStatus.notRecorded;
      _updateStatus('Login fields not ready. Reloading login page...');
      await _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_loginUri.toString())),
      );
    }
  }

  /// Polls the attendance form state once per second so the asynchronous
  /// `checkAttendance` rewrite (banner/S2, disabled fields/S3, Clock in
  /// label/S4) has time to land. Returns the last signals even on budget
  /// exhaustion so the caller can distinguish "seen but unconfirmed".
  Future<AttendanceFormSignals> _pollAttendanceFormState({
    required String earlyExitLabel,
    required bool Function(AttendanceFormState state) exitWhen,
    String pollLabel = 'state',
  }) async {
    AttendanceFormSignals last = const AttendanceFormSignals(
      state: AttendanceFormState.pending,
      signedInMessage: false,
    );

    for (var attempt = 1;
        attempt <= attendanceFormStateMaxAttempts;
        attempt += 1) {
      if (!mounted) return last;

      if (await _leftAttendanceForm()) {
        log('[AutoAttend] $pollLabel poll skipped — not on form page.');
        return last;
      }

      final raw = await _evaluateJavascript(attendanceFormStateJs);
      last = AttendanceFormSignals.parse(raw is String ? raw : null);
      log('[AutoAttend] $pollLabel poll $attempt/$attendanceFormStateMaxAttempts: '
          '${last.state.code} signedIn=${last.signedInMessage}');

      if (exitWhen(last.state)) {
        log('[AutoAttend] $pollLabel early exit ($earlyExitLabel) at attempt $attempt.');
        return last;
      }

      if (attempt < attendanceFormStateMaxAttempts) {
        if (last.signedInMessage) {
          _updateStatus(
            'Checking recorded attendance ($attempt/$attendanceFormStateMaxAttempts)...',
          );
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    return last;
  }

  Future<void> _injectAttendanceForm() async {
    if (_attendanceInjected || _attendanceInjectionInProgress) {
      log('[Inject] skipped — already injected/in-progress');
      return;
    }
    _attendanceInjectionInProgress = true;
    _updateStatus(
      'Preparing attendance form (${_selectedAttendanceType.label})...',
    );
    try {
      await WakelockPlus.enable();
    } catch (e) {
      log('[AutoAttend] Wakelock enable error: $e');
    }
    try {
      if (!await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.startService(
          serviceId: 2001,
          notificationTitle: 'HRMIS automation running',
          notificationText: 'Keep app open until verified',
        );
      }
    } catch (e) {
      log('[AutoAttend] Foreground service start error: $e');
    }

    bool injectionActive = true;
    try {
      // The checkAttendance rewrite lands seconds after onLoadStop, so poll
      // the form state instead of trusting a single first-paint reading.
      final formSignals = await _pollAttendanceFormState(
        earlyExitLabel: 'recorded/open',
        exitWhen: (state) =>
            state == AttendanceFormState.recorded ||
            state == AttendanceFormState.open,
      );

      if (formSignals.state == AttendanceFormState.recorded) {
        _attendanceInjected = true;
        _attendanceInjectionInProgress = false;
        _attendanceTodayStatus = AttendanceTodayStatus.recorded;
        _updateStatus(
          'Attendance already recorded${formSignals.signedInAt == null ? '' : ' (${formSignals.signedInAt})'}.',
        );
        log('[Inject] Short-circuit — already recorded, skipping form/GPS/save.');
        await _navigateToHomeForInspection();
        return;
      }

      if (formSignals.state == AttendanceFormState.pending &&
          formSignals.signedInMessage) {
        // T4: HRMIS prints "You are signed in today on HH:mm" but never
        // confirmed the state (checkAttendance stuck). Never guess a submit
        // here — a blind POST after a recorded day becomes a clock-out.
        _attendanceInjectionInProgress = false;
        _attendanceTodayStatus = AttendanceTodayStatus.failed;
        _updateStatus(
          attendanceUnconfirmedStatus(signedInAt: formSignals.signedInAt),
        );
        setState(() => _selectedTabIndex = 0);
        return;
      }

      // Pick once per session so retries keep the same description.
      final attendanceDescription = pickRandomAttendanceDescription();
      log('[Inject] description: $attendanceDescription');

      String? prepareResult;
      const maxPrepareAttempts = 5;

      for (var attempt = 1; attempt <= maxPrepareAttempts; attempt += 1) {
        if (attempt > 1) {
          _updateStatus(
            'Waiting for attendance form ($attempt/$maxPrepareAttempts)...',
          );
          await Future<void>.delayed(const Duration(seconds: 2));
        }

        if (!mounted) return;

        if (await _leftAttendanceForm()) {
          _attendanceInjectionInProgress = false;
          _attendanceTodayStatus = AttendanceTodayStatus.notRecorded;
          _updateStatus('Attendance form left before fields were ready.');
          log('[AutoAttend] Prepare skipped — not on form page.');
          return;
        }

        prepareResult = await _evaluateJavascript(prepareAttendanceFormJs(
            _selectedAttendanceType,
            description: attendanceDescription));
        if (prepareResult == 'attendance-prepared') break;

        log(
          '[AutoAttend] Attendance prepare attempt $attempt result: $prepareResult',
        );
      }

      if (prepareResult != 'attendance-prepared') {
        _attendanceInjectionInProgress = false;
        _attendanceTodayStatus = AttendanceTodayStatus.notRecorded;
        // A settled (already recorded) form reaching this point means the
        // state poll timed out without confirming — route it to home
        // inspection instead of the generic "not ready" branch.
        if (prepareResult == 'already-recorded') {
          _attendanceInjected = true;
          _attendanceTodayStatus = AttendanceTodayStatus.recorded;
          _updateStatus('Attendance already recorded.');
          log('[AutoAttend] Prepare reported settled form — going to home.');
          await _navigateToHomeForInspection();
          return;
        }
        _updateStatus(prepareFailureStatus(prepareResult));
        log('[AutoAttend] Attendance preparation result: $prepareResult');
        return;
      }

      // HRMIS only validates the office geofence for WFO; other types skip GPS.
      if (_selectedAttendanceType.requiresGeolocation) {
        _updateStatus('Waiting for GPS...');
        const maxGeolocationAttempts = 20;
        String? geolocationResult;

        for (var attempt = 1; attempt <= maxGeolocationAttempts; attempt += 1) {
          if (!mounted) return;

          if (await _leftAttendanceForm()) {
            _attendanceInjectionInProgress = false;
            _attendanceTodayStatus = AttendanceTodayStatus.notRecorded;
            _updateStatus('Attendance save skipped: not on form page.');
            log('[AutoAttend] Save skipped — not on form page.');
            return;
          }

          geolocationResult =
              await _evaluateJavascript(_checkGeolocationReadyJs);
          if (geolocationResult == 'geolocation-ready') break;

          log(
            '[AutoAttend] Geolocation attempt $attempt result: $geolocationResult',
          );
          _updateStatus(
            'Waiting for GPS ($attempt/$maxGeolocationAttempts)...',
          );
          await Future<void>.delayed(const Duration(seconds: 1));
        }

        if (geolocationResult != 'geolocation-ready') {
          _attendanceInjectionInProgress = false;
          _attendanceTodayStatus = AttendanceTodayStatus.notRecorded;
          _updateStatus(geolocationFailureStatus(geolocationResult));
          log('[AutoAttend] Geolocation not ready: $geolocationResult');
          return;
        }
      }

      _updateStatus('Saving attendance...');
      String? saveResult;
      const maxSaveAttempts = 3;

      for (var attempt = 1; attempt <= maxSaveAttempts; attempt += 1) {
        if (attempt > 1) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }

        saveResult = await _evaluateJavascript(_submitAttendanceFormJs);
        if (saveResult == 'attendance-save-submitted') break;
        log('[AutoAttend] Attendance save attempt $attempt result: $saveResult');
      }

      _attendanceInjectionInProgress = false;
      if (saveResult == 'attendance-save-submitted') {
        _attendanceInjected = true;
        _updateStatus('Attendance submitted. Verifying...');

        await Future<void>.delayed(const Duration(seconds: 5));

        if (!mounted) return;

        await _webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(_formUri.toString())),
        );

        await Future<void>.delayed(const Duration(seconds: 3));

        if (!mounted) return;

        // Same poll as the pre-injection check, but the asymmetry is
        // deliberate: the POST already happened, so any recorded evidence
        // (including the S1 server line for the refreshed page) confirms
        // success. Only an unambiguous open form downgrades to inconclusive.
        final verifySignals = await _pollAttendanceFormState(
          earlyExitLabel: 'recorded',
          exitWhen: (state) => state == AttendanceFormState.recorded,
          pollLabel: 'verify',
        );

        final verifyResult = verifySignals.state.code;

        if (verifyResult == 'attendance-recorded') {
          _attendanceTodayStatus = AttendanceTodayStatus.recorded;
          _updateStatus('Attendance verified as recorded.');
        } else {
          _attendanceTodayStatus = AttendanceTodayStatus.recorded;
          _updateStatus('Attendance submitted (verification inconclusive).');
        }

        await _navigateToHomeForInspection();
      } else {
        _attendanceTodayStatus = AttendanceTodayStatus.notRecorded;
        _updateStatus(saveFailureStatus(saveResult));
        log('[AutoAttend] Attendance save result: $saveResult');
      }
    } finally {
      if (injectionActive) {
        injectionActive = false;
        await _releaseKeepAlive();
      }
    }
  }

  Future<void> _inspectHomeAttendanceSummary() async {
    _homeInspectionInProgress = true;
    _updateStatus('Checking HRMIS summary...');

    await Future<void>.delayed(const Duration(seconds: 2));

    final result = await _evaluateJavascript('''
      (function () {
        try {
          function parseValue(text) {
            const value = Number.parseInt(
              String(text || '0').replace(/[^0-9-]/g, ''),
              10
            );
            return Number.isFinite(value) ? value : 0;
          }

          function readFromHtml(html) {
            const doc = new DOMParser().parseFromString(html, 'text/html');
            const valueText = (doc.querySelector('h2')?.textContent || '0').trim();
            const labelText = (
              doc.querySelector('.text-center')?.textContent || ''
            ).trim();

            return {
              value: parseValue(valueText),
              label: labelText,
              source: 'widget',
            };
          }

          function readHomeCard(labelNeedle) {
            const needle = labelNeedle.toLowerCase();
            const labels = Array.from(
              document.querySelectorAll('.text-center, span, p, div')
            );

            for (const label of labels) {
              const labelText = (label.textContent || '').trim();
              if (!labelText.toLowerCase().includes(needle)) continue;

              const parent = label.parentElement;
              const card = label.closest('.card, [class*="card"], .col, [class*="col"]');
              const valueElement =
                parent?.querySelector('h2') ||
                card?.querySelector('h2') ||
                label.previousElementSibling;

              const valueText = (valueElement?.textContent || '').trim();
              if (!valueText) continue;

              return {
                value: parseValue(valueText),
                label: labelText,
                source: 'home',
              };
            }

            return null;
          }

          function readWidget(path) {
            try {
              const request = new XMLHttpRequest();
              request.open('GET', path, false);
              request.setRequestHeader('Cache-Control', 'no-store');
              request.send(null);

              if (request.status >= 200 && request.status < 300) {
                return readFromHtml(request.responseText || '');
              }

              console.log(
                '[AutoAttend] Widget request failed:',
                path,
                request.status
              );
            } catch (error) {
              console.log('[AutoAttend] Widget XHR failed:', path, error);
            }

            return null;
          }

          const late =
            readHomeCard('Delay (minutes)') ||
            readHomeCard('Delay') ||
            readWidget('/attendance/widget/late') ||
            { value: 0, label: 'Delay (minutes)', source: 'fallback' };

          const absent =
            readHomeCard('Total of absence') ||
            readHomeCard('absence') ||
            readWidget('/attendance/widget/absent') ||
            { value: 0, label: 'Total of absence', source: 'fallback' };

          const summary = {
            lateMinutes: late.value,
            absenceDays: absent.value,
            lateLabel: late.label,
            absenceLabel: absent.label,
            lateSource: late.source,
            absenceSource: absent.source,
          };

          console.log('[AutoAttend] HRMIS summary:', JSON.stringify(summary));
          return JSON.stringify(summary);
        } catch (error) {
          console.log('[AutoAttend] HRMIS summary check failed:', error);
          return JSON.stringify({
            lateMinutes: 0,
            absenceDays: 0,
            error: String(error)
          });
        }
      })();
    ''');

    _homeInspectionInProgress = false;
    _homeInspectionCompleted = true;

    final summary = parseAttendanceSummary(result);
    if (summary == null) {
      _selectedTabIndex = 0;
      _updateStatus('HRMIS summary check failed.');
      log('[AutoAttend] Invalid summary result: $result');
      return;
    }

    setState(() {
      _lateMinutes = summary.lateMinutes;
      _absenceDays = summary.absenceDays;
      _selectedTabIndex = 0;
    });

    if (summary.hasWarning) {
      await NotificationService.showAttendanceWarning(
        lateMinutes: summary.lateMinutes,
        absenceDays: summary.absenceDays,
      );
      _updateStatus('HRMIS warning notification sent.');
      return;
    }

    _updateStatus('HRMIS summary is clear.');
  }

  Future<Uri?> _currentUri() async {
    final webUri = await _webViewController?.getUrl();
    if (webUri == null) return null;
    return Uri.tryParse(webUri.toString());
  }

  /// Returns true when the WebView is no longer on the attendance form route.
  Future<bool> _leftAttendanceForm() async {
    final currentUri = await _currentUri();
    return currentUri == null || !HrmisUri.isAttendanceForm(currentUri);
  }

  Future<bool> _hasLoggedInProfile() async {
    final result = await _evaluateJavascript('''
      (function () {
        try {
          const profileLinks = Array.from(
            document.querySelectorAll(
              'a.nav-link.dropdown-toggle, .nav-item.dropdown a, a[role="button"]'
            )
          );

          const hasProfileText = profileLinks.some((element) => {
            const text = (element.textContent || '').trim().toLowerCase();
            return text.includes('profile');
          });

          const hasProfileIcon = document.querySelector(
            'i.far.fa-user-circle.nav-icon'
          ) !== null;

          if (hasProfileText || hasProfileIcon) {
            console.log('[AutoAttend] Existing HRMIS session detected.');
            return true;
          }

          return false;
        } catch (error) {
          console.log('[AutoAttend] Profile session check failed:', error);
          return false;
        }
      })();
    ''');

    return result == true;
  }

  Future<dynamic> _evaluateJavascript(String source) async {
    try {
      final rawResult =
          await _webViewController?.evaluateJavascript(source: source);
      final result = normalizeJavascriptResult(rawResult);
      log('[AutoAttend] JS result: $result');
      return result;
    } catch (error, stackTrace) {
      log('[AutoAttend] JS evaluation error: $error');
      log('$stackTrace');
      _updateStatus('Automation error. Check console logs.');
      return null;
    }
  }

  void _updateStatus(String status) {
    if (!mounted) return;
    if (_status == status) return; // ⚡ Bolt: Prevent unnecessary re-renders of the heavy InAppWebView container
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedTabIndex,
          children: [
            Builder(
              builder: (innerContext) => DashboardView(
                attendanceStatus: _attendanceTodayStatus,
                automationStatus: _status,
                lateMinutes: _lateMinutes,
                absenceDays: _absenceDays,
                hasRequiredPermissions: _hasRequiredPermissions,
                isRequestingPermissions: _isRequestingPermissions,
                onRunAttendance: () => _onRunAttendancePressed(innerContext),
                onRequestPermissions: _requestPermissions,
                onOpenAutomation: () {
                  setState(() => _selectedTabIndex = 1);
                },
                selectedTypeLabel: _selectedAttendanceType.label,
              ),
            ),
            _buildAutomationView(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCredentialScreen,
        tooltip: 'Settings',
        child: const Icon(Icons.settings),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedTabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'Automation',
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationView() {
    return Stack(
      children: [
        Positioned.fill(
          child: !_hasRequiredPermissions
              ? _PermissionGuard(
                  isRequesting: _isRequestingPermissions,
                  onRequestPressed: _requestPermissions,
                )
              : !_automationRequested
                  ? const _IdleAutomationPlaceholder()
                  : InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(_loginUri.toString()),
                      ),
                      initialSettings: _settings,
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                      },
                      onLoadStart: (_, uri) {
                        final host = uri == null
                            ? null
                            : Uri.tryParse(uri.toString())?.host;
                        _updateStatus('Loading ${host ?? 'HRMIS'}...');
                      },
                      onLoadStop: (_, uri) => _handleLoadStop(uri),
                      onUpdateVisitedHistory: (_, uri, androidIsReload) =>
                          _handleLoadStop(uri),
                      onConsoleMessage: (_, consoleMessage) {
                        log(
                          '[WebView console:${consoleMessage.messageLevel}] '
                          '${consoleMessage.message}',
                        );
                      },
                      onGeolocationPermissionsShowPrompt: (_, origin) async {
                        return GeolocationPermissionShowPromptResponse(
                          origin: origin,
                          allow: true,
                          retain: true,
                        );
                      },
                      onPermissionRequest: (_, request) async {
                        return PermissionResponse(
                          resources: request.resources,
                          action: PermissionResponseAction.GRANT,
                        );
                      },
                      onReceivedError: (_, request, error) {
                        log(
                          '[WebView] Error ${error.type}: ${error.description} '
                          'for ${request.url}',
                        );
                      },
                    ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: _StatusOverlay(status: _status),
        ),
      ],
    );
  }
}

class _StatusOverlay extends StatelessWidget {
  const _StatusOverlay({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionGuard extends StatelessWidget {
  const _PermissionGuard({
    required this.isRequesting,
    required this.onRequestPressed,
  });

  final bool isRequesting;
  final VoidCallback onRequestPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Location and camera permissions are required before HRMIS loads.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isRequesting ? null : onRequestPressed,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(isRequesting ? 'Requesting...' : 'Grant permissions'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleAutomationPlaceholder extends StatelessWidget {
  const _IdleAutomationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.public_outlined,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              'Automation is idle.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose Run attendance on the Dashboard to pick WFO/WFH/SPJ.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal TaskHandler for flutter_foreground_task.
/// No periodic work — only keeps the service alive during injection.
class _HrmisKeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
