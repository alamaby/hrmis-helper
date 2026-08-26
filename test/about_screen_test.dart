import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:codex_auto_attend/about_screen.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

const _packageInfoChannel = MethodChannel(
  'dev.fluttercommunity.plus/package_info',
);

void resetPackageInfoChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_packageInfoChannel, null);
}

void main() {
  setUp(resetPackageInfoChannel);
  tearDown(resetPackageInfoChannel);

  // Must run before any setMockInitialValues call: it caches a static
  // PackageInfo inside the plugin, which would bypass the failing channel.
  testWidgets('AboutScreen shows error banner when PackageInfo fails',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageInfoChannel, (call) async {
      throw MissingPluginException('simulated: no platform implementation');
    });

    await tester.pumpWidget(wrap(const AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load app info'), findsOneWidget);
  });

  testWidgets('AboutScreen shows app info from PackageInfo', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'HRMIS Helper',
      packageName: 'com.alamaby.hrmis_helper',
      version: '1.2.0',
      buildNumber: '6',
      buildSignature: '',
      installerStore: '',
    );

    await tester.pumpWidget(wrap(const AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('HRMIS Helper'), findsAtLeastNWidgets(1));
    expect(find.text('com.alamaby.hrmis_helper'), findsOneWidget);
    expect(find.text('1.2.0 (6)'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('AboutScreen hides build number display for build 1',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'HRMIS Helper',
      packageName: 'com.alamaby.hrmis_helper',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: '',
    );

    await tester.pumpWidget(wrap(const AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('1.0.0 (1)'), findsNothing);
  });
}
