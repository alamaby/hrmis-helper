# HRMIS Helper

HRMIS Helper is a Flutter application that assists HRMIS workflows for `https://hrmis.neuron.id` using an embedded WebView.

The app loads HRMIS in `flutter_inappwebview`, injects JavaScript for login and attendance form submission, requests the required device permissions, and shows a small status overlay while the automation is running.

## Features

- Automated HRMIS login using credentials from a local `.env` file.
- Existing session detection, so the app can skip login when HRMIS is already authenticated.
- Automatic navigation to the attendance form.
- WFO attendance selection and description injection.
- GPS wait period before saving attendance.
- Detection for already-recorded attendance messages.
- Android launcher icon support using `assets/images/app_logo.png`.

## Requirements

- Flutter 3.41 or newer
- Dart 3.11 or newer
- Android SDK
- A physical Android device or emulator with location support

## Setup

1. Install dependencies:

   ```bash
   flutter pub get
   ```

2. Create a local `.env` file from the example:

   ```bash
   cp .env.example .env
   ```

3. Fill in your HRMIS credentials:

   ```env
   HRMIS_USERNAME=your_username
   HRMIS_PASSWORD=your_password
   ```

4. Make sure the app logo exists at:

   ```text
   assets/images/app_logo.png
   ```

5. Generate Android launcher icons when the logo changes:

   ```bash
   flutter pub run flutter_launcher_icons
   ```

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

Location and camera permissions are requested before loading the WebView.

## Environment Variables

| Variable | Description |
| --- | --- |
| `HRMIS_USERNAME` | HRMIS login username |
| `HRMIS_PASSWORD` | HRMIS login password |

Never commit the `.env` file. Use `.env.example` as the public template.

## Project Structure

```text
lib/
  config.dart        # Environment loading
  main.dart          # WebView, permission guard, and automation flow
assets/images/
  app_logo.png       # Source app logo
android/
  app/               # Android app configuration and resources
```

## Notes

This project is designed for personal/internal HRMIS attendance assistance. Make sure usage complies with your organization's HRMIS and attendance policies.
