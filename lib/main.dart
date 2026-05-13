import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.load();
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
  static const String _formPath = '/attendance/dashboard/form';

  InAppWebViewController? _webViewController;
  String _status = 'Checking permissions...';
  bool _hasRequiredPermissions = false;
  bool _loginInjected = false;
  bool _loginInjectionInProgress = false;
  bool _formNavigationTriggered = false;
  bool _attendanceInjected = false;
  bool _attendanceInjectionInProgress = false;
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

  Future<void> _injectLogin() async {
    if (!Config.hasCredentials) {
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
      _updateStatus('Attendance already recorded.');
      return;
    }

    final prepareResult = await _evaluateJavascript('''
      (function () {
        try {
          const description = document.getElementById('start_description');
          const wfoOption = document.getElementById('flag_location-WFO');

          if (!description || !wfoOption) {
            console.log('[AutoAttend] Attendance elements not found.');
            return 'missing-attendance-elements';
          }

          description.value = 'Bismillah, semangat bekerja!';
          description.dispatchEvent(new Event('input', { bubbles: true }));
          description.dispatchEvent(new Event('change', { bubbles: true }));

          console.log('[AutoAttend] Selecting WFO location option.');
          wfoOption.click();
          return 'attendance-prepared';
        } catch (error) {
          console.log('[AutoAttend] Attendance preparation failed:', error);
          return 'attendance-error';
        }
      })();
    ''');

    if (prepareResult != 'attendance-prepared') {
      _attendanceInjectionInProgress = false;
      _updateStatus('Attendance form not ready.');
      print('[AutoAttend] Attendance preparation result: $prepareResult');
      return;
    }

    _updateStatus('Waiting for GPS (10s)...');
    await Future<void>.delayed(const Duration(seconds: 10));

    if (!mounted) return;
    final currentUri = await _currentUri();
    if (currentUri == null || !_isAttendanceForm(currentUri)) {
      _attendanceInjectionInProgress = false;
      _updateStatus('Attendance save skipped: not on form page.');
      print('[AutoAttend] Save skipped. Current URL: $currentUri');
      return;
    }

    _updateStatus('Saving attendance...');
    final saveResult = await _evaluateJavascript('''
      (function () {
        try {
          const saveButton = document.getElementById('attendance-saveButton');

          if (!saveButton) {
            console.log('[AutoAttend] Save button not found.');
            return 'missing-save-button';
          }

          console.log('[AutoAttend] Clicking attendance save button.');
          saveButton.click();
          return 'attendance-save-submitted';
        } catch (error) {
          console.log('[AutoAttend] Attendance save failed:', error);
          return 'attendance-save-error';
        }
      })();
    ''');

    _attendanceInjectionInProgress = false;
    if (saveResult == 'attendance-save-submitted') {
      _attendanceInjected = true;
      _updateStatus('Attendance save submitted.');
    } else {
      _updateStatus('Attendance save not submitted.');
      print('[AutoAttend] Attendance save result: $saveResult');
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
      final result =
          await _webViewController?.evaluateJavascript(source: source);
      print('[AutoAttend] JS result: $result');
      return result;
    } catch (error, stackTrace) {
      print('[AutoAttend] JS evaluation error: $error');
      print(stackTrace);
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
      body: SafeArea(
        child: Stack(
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
                        final host = uri == null
                            ? null
                            : Uri.tryParse(uri.toString())?.host;
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
        ),
      ),
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
