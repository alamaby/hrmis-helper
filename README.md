# HRMIS Helper

HRMIS Helper is a Flutter application that assists HRMIS workflows for `https://hrmis.neuron.id` using an embedded WebView.

The app loads HRMIS in `flutter_inappwebview`, injects JavaScript for login and attendance form submission, requests the required device permissions, and shows a small status overlay while the automation is running.

## Features

- Automated HRMIS login using credentials stored in Android Keystore (`flutter_secure_storage`).
- In-app credential management screen with validation and password visibility toggle.
- Attendance type selection (WFO / WFH / SPJ) shown before the automation runs.
- Geolocation wait is skipped for WFH and SPJ — HRMIS only validates the office geofence for WFO.
- Existing session detection, so the app can skip login when HRMIS is already authenticated.
- Automatic navigation to the attendance form.
- WFO attendance selection and description injection.
- GPS wait period before saving attendance.
- Detection for already-recorded attendance messages.
- Android notifications for HRMIS delay and absence warnings after attendance.
- Dashboard view with today's attendance status, delay minutes, and absence days.
- Bottom navigation for switching between Dashboard and Automation WebView.
- About screen showing app name, package, version, and build number at runtime.
- Android launcher icon support using `assets/images/app_logo.png`.

## Requirements

- Flutter 3.41 or newer
- Dart 3.11 or newer
- Android SDK
- Android 6.0 (API 23) or newer
- A physical Android device or emulator with location support

## Setup

1. Install dependencies:

   ```bash
   flutter pub get
   ```

2. Make sure the app logo exists at:

   ```text
   assets/images/app_logo.png
   ```

3. Generate Android launcher icons when the logo changes:

   ```bash
   flutter pub run flutter_launcher_icons
   ```

4. Run the app; on first launch it opens the credential screen. Enter your
   HRMIS username and password there — they are saved to encrypted device
   storage (Android Keystore) and never leave the device.

Credentials can be updated or cleared anytime from the settings FAB on the
dashboard.

## Running

Run the app on a connected Android device:

```bash
flutter run
```

Build a debug APK:

```bash
flutter build apk --debug
```

The generated APK is available at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Build the arm64 release APK used for device installation:

```bash
flutter build apk --target-platform android-arm64 --split-per-abi
```

Gradle automatically creates a copy of every built APK with a friendly name:

```text
build/app/outputs/flutter-apk/HRMIS-Helper-v{version}({build})-{abi}-{buildType}.apk
```

Example: `HRMIS-Helper-v1.2.0(6)-arm64-v8a-release.apk`. The original
`app-*.apk` files remain in place for Flutter's post-build checks.

## Testing

Unit tests cover the extracted core logic (URL routing, summary parsing,
JavaScript result normalization, status messages). Widget tests cover the
dashboard, credential screen, and about screen.

```bash
flutter test
```

With coverage report:

```bash
flutter test --coverage
```

## Android Package

The Android package name is:

```text
com.alamaby.hrmis_helper
```

## Permissions

The Android app requests:

- `INTERNET`
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `CAMERA`
- `POST_NOTIFICATIONS`

Location and camera permissions are requested before loading the WebView.
Notification permission is requested so the app can alert users about HRMIS delay or absence information.

## Project Structure

```text
lib/
  main.dart                 # App entry, WebView automation flow, status overlay
  dashboard_view.dart       # Dashboard widgets (header, metrics, timeline)
  config.dart               # Secure credential storage wrapper
  credential_screen.dart    # Credential input UI
  about_screen.dart         # Runtime app info screen
  notification_service.dart # Local Android notifications
  core/
    app_logger.dart         # Release-safe logger (silent in release builds)
    hrmis_uri.dart          # HRMIS URL routing helpers
    attendance_type.dart    # WFO/WFH/SPJ enum with HRMIS radio mapping
    attendance_prepare_js.dart # Injected JS builder per attendance type
    attendance_summary.dart # Attendance summary model + JSON parser
    javascript_result.dart  # WebView JS result normalization
    status_messages.dart    # Automation failure message mappers
assets/images/
  app_logo.png              # Source app logo
android/
  app/                      # Android app configuration and resources
test/
  *.dart                    # Unit and widget tests
```

## Notes

This project is designed for personal/internal HRMIS attendance assistance. Make sure usage complies with your organization's HRMIS and attendance policies.
