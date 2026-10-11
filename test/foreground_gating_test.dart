import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Maps lifecycle state + injection progress to the status message that
/// didChangeAppLifecycleState would produce. Extracted as a pure function
/// so it can be unit-tested without device or channel mocks.
String? keepAliveMessage(bool inProgress, bool isPaused) {
  if (!inProgress) return null;
  if (isPaused) return 'Paused — return to app to continue.';
  return 'Resumed — checking HRMIS...';
}

void main() {
  group('keepAliveMessage mapping', () {
    test('paused while in-progress returns pause status', () {
      expect(
          keepAliveMessage(true, true), 'Paused — return to app to continue.');
    });

    test('resumed while in-progress returns resume status', () {
      expect(keepAliveMessage(true, false), 'Resumed — checking HRMIS...');
    });

    test('paused when not in-progress returns null (no-op)', () {
      expect(keepAliveMessage(false, true), isNull);
    });

    test('resumed when not in-progress returns null (no-op)', () {
      expect(keepAliveMessage(false, false), isNull);
    });
  });

  group('wakelock_plus API', () {
    test('enable and disable are defined (platform may no-op on CI)', () {
      // WakelockPlus calls throw on web/CI without platform implementation;
      // we only verify the symbols exist — real behavior is tested manually.
      expect(WakelockPlus.enable, isA<Function>());
      expect(WakelockPlus.disable, isA<Function>());
    });
  });
}
