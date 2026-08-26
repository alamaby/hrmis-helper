import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import 'attendance_type_picker.dart';
import 'config.dart';
import 'core/app_logger.dart';
import 'core/attendance_prepare_js.dart';
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
    if (!locList || !locList.value) {
      return 'location-list-missing';
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

class _AttendanceAutomationPageState extends State<AttendanceAutomationPage> {
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

  final InAppWebViewSettings _settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    allowUniversalAccessFromFileURLs: true,
    allowFileAccessFromFileURLs: true,
    safeBrowsingEnabled: false,
    geolocationEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    mediaPlaybackRequiresUserGesture: false,
  );

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    if (!Config.hasCredentials) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCredentialScreen();
      });
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
          ? 'Opening HRMIS...'
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
          ? 'Opening HRMIS...'
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
      _runAttendanceAutomation();
    }
  }

  Future<void> _handleLoadStop(WebUri? webUri) async {
    if (webUri == null) return;

    final uri = Uri.tryParse(webUri.toString());
    if (uri == null) return;

    final url = uri.toString();
    log('[WebView] Load stopped: $url');

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

  Future<void> _onRunAttendancePressed() async {
    final type = await showAttendanceTypePicker(context);
    if (type == null || !mounted) return;

    setState(() => _selectedAttendanceType = type);
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
    _attendanceTodayStatus = AttendanceTodayStatus.checking;

    setState(() {
      _selectedTabIndex = 1;
      _status = _hasRequiredPermissions
          ? 'Opening HRMIS...'
          : 'Location and camera permissions are required.';
    });

    if (!_hasRequiredPermissions) return;

    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_loginUri.toString())),
    );
  }

  Future<void> _navigateToHomeForInspection() async {
    _homeInspectionRequested = true;
    _homeInspectionCompleted = false;
    _updateStatus('Opening HRMIS home...');

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

  Future<void> _injectAttendanceForm() async {
    _attendanceInjectionInProgress = true;
    _updateStatus(
      'Preparing attendance form (${_selectedAttendanceType.label})...',
    );

    final recordedResult = await _evaluateJavascript('''
      (function () {
        try {
          const messages = Array.from(
            document.querySelectorAll(
              '.messages-group, .messages-group strong, .messages-group .messages, .messages-group span'
            )
          ).map((element) => (element.textContent || '').trim().toLowerCase());

          const hasRecordedMessage = messages.some(
            (message) => message.includes('attendance has been recorded')
          );

          if (hasRecordedMessage) {
            console.log('[AutoAttend] Attendance has already been recorded.');
            return 'attendance-already-recorded';
          }

          return 'attendance-not-recorded';
        } catch (error) {
          console.log('[AutoAttend] Attendance message check failed:', error);
          return 'attendance-message-check-error';
        }
      })();
    ''');

    if (recordedResult == 'attendance-already-recorded') {
      _attendanceInjected = true;
      _attendanceInjectionInProgress = false;
      _attendanceTodayStatus = AttendanceTodayStatus.recorded;
      _updateStatus('Attendance already recorded.');
      await _navigateToHomeForInspection();
      return;
    }

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

      final currentUri = await _currentUri();
      if (currentUri == null || !HrmisUri.isAttendanceForm(currentUri)) {
        _attendanceInjectionInProgress = false;
        _attendanceTodayStatus = AttendanceTodayStatus.notRecorded;
        _updateStatus('Attendance form left before fields were ready.');
        log('[AutoAttend] Prepare skipped. Current URL: $currentUri');
        return;
      }

      prepareResult = await _evaluateJavascript(
          prepareAttendanceFormJs(_selectedAttendanceType));
      if (prepareResult == 'attendance-prepared') break;

      log(
        '[AutoAttend] Attendance prepare attempt $attempt result: $prepareResult',
      );
    }

    if (prepareResult != 'attendance-prepared') {
      _attendanceInjectionInProgress = false;
      _attendanceTodayStatus = AttendanceTodayStatus.notRecorded;
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

        final currentUri = await _currentUri();
        if (currentUri == null || !HrmisUri.isAttendanceForm(currentUri)) {
          _attendanceInjectionInProgress = false;
          _attendanceTodayStatus = AttendanceTodayStatus.notRecorded;
          _updateStatus('Attendance save skipped: not on form page.');
          log('[AutoAttend] Save skipped. Current URL: $currentUri');
          return;
        }

        geolocationResult = await _evaluateJavascript(_checkGeolocationReadyJs);
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

      final verifyResult = await _evaluateJavascript('''
        (function () {
          try {
            const messages = Array.from(
              document.querySelectorAll('.alert, .message, .success, .error, [role="alert"]')
            );
            for (const el of messages) {
              const text = (el.textContent || '').toLowerCase();
              if (text.includes('sudah') || text.includes('already') || text.includes('tercatat') || text.includes('recorded')) {
                return 'attendance-already-recorded';
              }
            }
            return 'attendance-not-recorded';
          } catch (error) {
            return 'verify-error';
          }
        })();
      ''');

      if (verifyResult == 'attendance-already-recorded') {
        _attendanceTodayStatus = AttendanceTodayStatus.recorded;
        _updateStatus('Attendance verified as recorded.');
      } else {
        _attendanceTodayStatus = AttendanceTodayStatus.recorded;
        _updateStatus('Attendance submitted (verification inconclusive).');
      }

      await _navigateToHomeForInspection();
    } else {
      _attendanceTodayStatus = AttendanceTodayStatus.notRecorded;
      _updateStatus('Attendance save not submitted.');
      log('[AutoAttend] Attendance save result: $saveResult');
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
            DashboardView(
              attendanceStatus: _attendanceTodayStatus,
              automationStatus: _status,
              lateMinutes: _lateMinutes,
              absenceDays: _absenceDays,
              hasRequiredPermissions: _hasRequiredPermissions,
              isRequestingPermissions: _isRequestingPermissions,
              onRunAttendance: _onRunAttendancePressed,
              onRequestPermissions: _requestPermissions,
              onOpenAutomation: () {
                setState(() => _selectedTabIndex = 1);
              },
              selectedTypeLabel: _selectedAttendanceType.label,
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
          child: _hasRequiredPermissions
              ? InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(_loginUri.toString()),
                  ),
                  initialSettings: _settings,
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (_, uri) {
                    final host =
                        uri == null ? null : Uri.tryParse(uri.toString())?.host;
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
                )
              : _PermissionGuard(
                  isRequesting: _isRequestingPermissions,
                  onRequestPressed: _requestPermissions,
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
