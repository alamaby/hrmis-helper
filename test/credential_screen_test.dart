import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/config.dart';
import 'package:codex_auto_attend/credential_screen.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
    return null;
  });
}

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  setUp(() {
    mockSecureStorage();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  group('CredentialScreen', () {
    testWidgets('renders username and password fields', (tester) async {
      await Config.clear();
      await tester.pumpWidget(wrap(const CredentialScreen()));

      expect(find.text('Code / Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Save Credentials'), findsOneWidget);
    });

    testWidgets('hides clear button when no credentials are stored',
        (tester) async {
      await Config.clear();
      await tester.pumpWidget(wrap(const CredentialScreen()));

      expect(find.text('Clear Stored Credentials'), findsNothing);
    });

    testWidgets('shows validation errors when saving empty form',
        (tester) async {
      await Config.clear();
      await tester.pumpWidget(wrap(const CredentialScreen()));

      await tester.tap(find.text('Save Credentials'));
      await tester.pump();

      expect(find.text('Please enter your username'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await Config.clear();
      await tester.pumpWidget(wrap(const CredentialScreen()));

      final passwordEditable = find.byType(EditableText).at(1);
      expect(
        tester.widget<EditableText>(passwordEditable).obscureText,
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(
        tester.widget<EditableText>(passwordEditable).obscureText,
        isFalse,
      );
    });

    testWidgets('saves valid credentials and pops with true', (tester) async {
      await Config.clear();
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CredentialScreen(),
                    ),
                  );
                  if (saved != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved: $saved')),
                    );
                  }
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'myuser');
      await tester.enterText(find.byType(TextFormField).at(1), 'mypass');

      await tester.tap(find.text('Save Credentials'));
      await tester.pumpAndSettle();

      expect(Config.username, 'myuser');
      expect(Config.hasCredentials, isTrue);
      expect(find.text('Saved: true'), findsOneWidget);
    });
  });
}
