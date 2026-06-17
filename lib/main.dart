import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config.dart';
import 'notification_service.dart';

const _attendanceDescriptionText = 'Bismillah, semangat bekerja!';

const _prepareAttendanceFormJs = '''
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

  function selectWfoIfPresent() {
    const radios = Array.from(document.querySelectorAll('input[type="radio"]'));
    const labels = Array.from(document.querySelectorAll('label'));
    const candidates = [
      document.getElementById('flag_location-WFO'),
      radios.find((element) => {
        const id = (element.id || '').toLowerCase();
        const value = (element.value || '').toLowerCase();
        return id.includes('wfo') || value.includes('wfo');
      }),
      labels.find((element) => {
        const text = (element.textContent || '').trim().toLowerCase();
        const forId = (element.getAttribute('for') || '').toLowerCase();
        return text.includes('work from office') || forId.includes('wfo');
      }),
    ].filter(Boolean);

    for (const element of candidates) {
      element.click();
      console.log('[AutoAttend] WFO option selected:', element.id || element.value);
      return true;
    }

    console.log('[AutoAttend] WFO option not present; continuing without it.');
    return false;
  }

  try {
    const description = findDescriptionField();
    if (!description) {
      console.log('[AutoAttend] Description field not found.');
      return 'missing-description';
    }

    description.value = '$_attendanceDescriptionText';
    description.dispatchEvent(new Event('input', { bubbles: true }));
    description.dispatchEvent(new Event('change', { bubbles: true }));

    selectWfoIfPresent();
    return 'attendance-prepared';
  } catch (error) {
    console.log('[AutoAttend] Attendance preparation failed:', error);
    return 'attendance-error';
  }
})();
''';

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
  static const String _formPath = '/attendance/dashboard/form';

  InAppWebViewController? _webViewController;
  int _selectedTabIndex = 0;
  String _status = 'Checking permissions...';
  _AttendanceTodayStatus _attendanceTodayStatus =
      _AttendanceTodayStatus.checking;
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

  Future<void> _handleLoadStop(WebUri? webUri) async {
    if (webUri == null) return;

    final uri = Uri.tryParse(webUri.toString());
    if (uri == null) return;

    final url = uri.toString();
    print('[WebView] Load stopped: $url');

    if (_isHomeInspectionPage(uri) &&
        _homeInspectionRequested &&
        !_homeInspectionInProgress &&
        !_homeInspectionCompleted) {
      await _inspectHomeAttendanceSummary();
      return;
    }

    if (_isLoginPage(uri) && !_loginInjected && !_loginInjectionInProgress) {
      await _injectLogin();
      return;
    }

    if (_isAttendanceForm(uri) &&
        !_attendanceInjected &&
        !_attendanceInjectionInProgress) {
      await _injectAttendanceForm();
      return;
    }

    if (_shouldNavigateToAttendanceForm(uri)) {
      await _navigateToAttendanceForm(uri);
    }
  }

  bool _isLoginPage(Uri uri) {
    return uri.scheme == 'https' &&
        uri.host == 'hrmis.neuron.id' &&
        uri.path == '/doornew';
  }

  bool _isHomeInspectionPage(Uri uri) => _isLoginPage(uri);

  bool _isAttendanceForm(Uri uri) {
    return uri.scheme == 'https' &&
        uri.host == 'hrmis.neuron.id' &&
        uri.path == _formPath;
  }

  bool _isHrmisPage(Uri uri) {
    return uri.scheme == 'https' && uri.host == 'hrmis.neuron.id';
  }

  bool _shouldNavigateToAttendanceForm(Uri uri) {
    if (!_isHrmisPage(uri)) return false;
    if (_isAttendanceForm(uri)) return false;
    if (_formNavigationTriggered || _attendanceInjected) return false;

    // After a successful login HRMIS can land on a home/dashboard page first.
    // Send the WebView directly to the known attendance form route.
    return _loginInjected &&
        (uri.path == '/' || uri.path.contains('dashboard'));
  }

  Future<void> _navigateToAttendanceForm(Uri currentUri) async {
    _formNavigationTriggered = true;
    _updateStatus('Opening attendance form...');
    print('[AutoAttend] Redirecting from $currentUri to $_formUri');

    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_formUri.toString())),
    );
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
    _attendanceTodayStatus = _AttendanceTodayStatus.checking;

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
      _attendanceTodayStatus = _AttendanceTodayStatus.failed;
      _updateStatus('Missing HRMIS credentials in .env.');
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
    if (currentUri == null || !_isLoginPage(currentUri)) {
      _loginInjectionInProgress = false;
      print('[AutoAttend] Login injection skipped. Current URL: $currentUri');
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

      print('[AutoAttend] Login attempt $attempt result: $result');
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    _loginInjectionInProgress = false;

    if (!_loginInjected && mounted) {
      _attendanceTodayStatus = _AttendanceTodayStatus.notRecorded;
      _updateStatus('Login fields not ready. Reloading login page...');
      await _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_loginUri.toString())),
      );
    }
  }

  Future<void> _injectAttendanceForm() async {
    _attendanceInjectionInProgress = true;
    _updateStatus('Preparing attendance form...');

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
      _attendanceTodayStatus = _AttendanceTodayStatus.recorded;
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
      if (currentUri == null || !_isAttendanceForm(currentUri)) {
        _attendanceInjectionInProgress = false;
        _attendanceTodayStatus = _AttendanceTodayStatus.notRecorded;
        _updateStatus('Attendance form left before fields were ready.');
        print('[AutoAttend] Prepare skipped. Current URL: $currentUri');
        return;
      }

      prepareResult = await _evaluateJavascript(_prepareAttendanceFormJs);
      if (prepareResult == 'attendance-prepared') break;

      print(
        '[AutoAttend] Attendance prepare attempt $attempt result: $prepareResult',
      );
    }

    if (prepareResult != 'attendance-prepared') {
      _attendanceInjectionInProgress = false;
      _attendanceTodayStatus = _AttendanceTodayStatus.notRecorded;
      _updateStatus(_prepareFailureStatus(prepareResult));
      print('[AutoAttend] Attendance preparation result: $prepareResult');
      return;
    }

    _updateStatus('Waiting for GPS (10s)...');
    await Future<void>.delayed(const Duration(seconds: 10));

    if (!mounted) return;
    final currentUri = await _currentUri();
    if (currentUri == null || !_isAttendanceForm(currentUri)) {
      _attendanceInjectionInProgress = false;
      _attendanceTodayStatus = _AttendanceTodayStatus.notRecorded;
      _updateStatus('Attendance save skipped: not on form page.');
      print('[AutoAttend] Save skipped. Current URL: $currentUri');
      return;
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
      print(
          '[AutoAttend] Attendance save attempt $attempt result: $saveResult');
    }

    _attendanceInjectionInProgress = false;
    if (saveResult == 'attendance-save-submitted') {
      _attendanceInjected = true;
      _attendanceTodayStatus = _AttendanceTodayStatus.recorded;
      _updateStatus('Attendance save submitted.');
      await _navigateToHomeForInspection();
    } else {
      _attendanceTodayStatus = _AttendanceTodayStatus.notRecorded;
      _updateStatus('Attendance save not submitted.');
      print('[AutoAttend] Attendance save result: $saveResult');
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

    final summary = _parseAttendanceSummary(result);
    if (summary == null) {
      _selectedTabIndex = 0;
      _updateStatus('HRMIS summary check failed.');
      print('[AutoAttend] Invalid summary result: $result');
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

  _AttendanceSummary? _parseAttendanceSummary(dynamic result) {
    try {
      dynamic decoded = result;

      if (decoded is String) {
        decoded = jsonDecode(decoded);
        if (decoded is String) {
          decoded = jsonDecode(decoded);
        }
      }

      if (decoded is! Map<String, dynamic>) return null;

      return _AttendanceSummary(
        lateMinutes: (decoded['lateMinutes'] as num?)?.toInt() ?? 0,
        absenceDays: (decoded['absenceDays'] as num?)?.toInt() ?? 0,
      );
    } catch (error) {
      print('[AutoAttend] Summary parse failed: $error');
      return null;
    }
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
      final result = _normalizeJavascriptResult(rawResult);
      print('[AutoAttend] JS result: $result');
      return result;
    } catch (error, stackTrace) {
      print('[AutoAttend] JS evaluation error: $error');
      print(stackTrace);
      _updateStatus('Automation error. Check console logs.');
      return null;
    }
  }

  dynamic _normalizeJavascriptResult(dynamic result) {
    if (result is! String || result.length < 2) return result;

    final trimmed = result.trim();
    if (!trimmed.startsWith('"') || !trimmed.endsWith('"')) return result;

    try {
      final decoded = jsonDecode(trimmed);
      return decoded is String ? decoded : result;
    } catch (_) {
      return result;
    }
  }

  void _updateStatus(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  String _prepareFailureStatus(String? result) {
    return switch (result) {
      'missing-description' =>
        'Description field not found. Stay on the attendance form and retry.',
      'attendance-error' => 'Attendance form preparation failed.',
      _ => 'Attendance form not ready.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedTabIndex,
          children: [
            _DashboardView(
              attendanceStatus: _attendanceTodayStatus,
              automationStatus: _status,
              lateMinutes: _lateMinutes,
              absenceDays: _absenceDays,
              hasRequiredPermissions: _hasRequiredPermissions,
              isRequestingPermissions: _isRequestingPermissions,
              onRunAttendance: _runAttendanceAutomation,
              onRequestPermissions: _requestPermissions,
              onOpenAutomation: () {
                setState(() => _selectedTabIndex = 1);
              },
            ),
            _buildAutomationView(),
          ],
        ),
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
                    print(
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
                    print(
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

enum _AttendanceTodayStatus {
  checking,
  recorded,
  notRecorded,
  failed,
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.attendanceStatus,
    required this.automationStatus,
    required this.lateMinutes,
    required this.absenceDays,
    required this.hasRequiredPermissions,
    required this.isRequestingPermissions,
    required this.onRunAttendance,
    required this.onRequestPermissions,
    required this.onOpenAutomation,
  });

  final _AttendanceTodayStatus attendanceStatus;
  final String automationStatus;
  final int lateMinutes;
  final int absenceDays;
  final bool hasRequiredPermissions;
  final bool isRequestingPermissions;
  final VoidCallback onRunAttendance;
  final VoidCallback onRequestPermissions;
  final VoidCallback onOpenAutomation;

  bool get _hasWarning => lateMinutes > 0 || absenceDays > 0;
  bool get _canRunAttendance =>
      hasRequiredPermissions &&
      attendanceStatus != _AttendanceTodayStatus.recorded;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        _DashboardHeader(
          attendanceStatus: attendanceStatus,
          hasWarning: _hasWarning,
        ),
        const SizedBox(height: 16),
        _ActionPanel(
          attendanceStatus: attendanceStatus,
          automationStatus: automationStatus,
          hasRequiredPermissions: hasRequiredPermissions,
          isRequestingPermissions: isRequestingPermissions,
          canRunAttendance: _canRunAttendance,
          onRunAttendance: onRunAttendance,
          onRequestPermissions: onRequestPermissions,
          onOpenAutomation: onOpenAutomation,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
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
              child: _MetricCard(
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
        _StatusTimeline(
          attendanceStatus: attendanceStatus,
          lateMinutes: lateMinutes,
          absenceDays: absenceDays,
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.attendanceStatus,
    required this.hasWarning,
  });

  final _AttendanceTodayStatus attendanceStatus;
  final bool hasWarning;

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
              _StatusPill(
                text: _statusText(attendanceStatus),
                foregroundColor: _statusColor(attendanceStatus),
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

  static String _statusText(_AttendanceTodayStatus status) {
    return switch (status) {
      _AttendanceTodayStatus.checking => 'Checking',
      _AttendanceTodayStatus.recorded => 'Recorded',
      _AttendanceTodayStatus.notRecorded => 'Not recorded',
      _AttendanceTodayStatus.failed => 'Needs action',
    };
  }

  static Color _statusColor(_AttendanceTodayStatus status) {
    return switch (status) {
      _AttendanceTodayStatus.checking => const Color(0xFF2563EB),
      _AttendanceTodayStatus.recorded => const Color(0xFF047857),
      _AttendanceTodayStatus.notRecorded => const Color(0xFFB45309),
      _AttendanceTodayStatus.failed => const Color(0xFFB91C1C),
    };
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.attendanceStatus,
    required this.automationStatus,
    required this.hasRequiredPermissions,
    required this.isRequestingPermissions,
    required this.canRunAttendance,
    required this.onRunAttendance,
    required this.onRequestPermissions,
    required this.onOpenAutomation,
  });

  final _AttendanceTodayStatus attendanceStatus;
  final String automationStatus;
  final bool hasRequiredPermissions;
  final bool isRequestingPermissions;
  final bool canRunAttendance;
  final VoidCallback onRunAttendance;
  final VoidCallback onRequestPermissions;
  final VoidCallback onOpenAutomation;

  @override
  Widget build(BuildContext context) {
    final message = switch (attendanceStatus) {
      _AttendanceTodayStatus.recorded =>
        'Attendance has been recorded for today.',
      _AttendanceTodayStatus.notRecorded =>
        'Attendance is not confirmed yet. Run the automation again.',
      _AttendanceTodayStatus.failed =>
        'Automation needs attention before it can continue.',
      _AttendanceTodayStatus.checking => 'Automation is checking HRMIS.',
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({
    required this.attendanceStatus,
    required this.lateMinutes,
    required this.absenceDays,
  });

  final _AttendanceTodayStatus attendanceStatus;
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
          _TimelineRow(
            icon: Icons.login_rounded,
            title: 'Attendance status',
            value: switch (attendanceStatus) {
              _AttendanceTodayStatus.recorded => 'Recorded',
              _AttendanceTodayStatus.notRecorded => 'Not confirmed',
              _AttendanceTodayStatus.failed => 'Needs attention',
              _AttendanceTodayStatus.checking => 'Checking',
            },
          ),
          const Divider(height: 22),
          _TimelineRow(
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

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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

class _AttendanceSummary {
  const _AttendanceSummary({
    required this.lateMinutes,
    required this.absenceDays,
  });

  final int lateMinutes;
  final int absenceDays;

  bool get hasWarning => lateMinutes > 0 || absenceDays > 0;
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
