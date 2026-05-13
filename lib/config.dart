import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  const Config._();

  static String get username => dotenv.env['HRMIS_USERNAME']?.trim() ?? '';
  static String get password => dotenv.env['HRMIS_PASSWORD']?.trim() ?? '';

  static bool get hasCredentials => username.isNotEmpty && password.isNotEmpty;

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (error) {
      // Keep the app bootable so the UI can clearly report missing config.
      print('[Config] Failed to load .env: $error');
    }
  }
}
