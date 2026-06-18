import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Config {
  const Config._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _usernameKey = 'hrmis_username';
  static const String _passwordKey = 'hrmis_password';

  static String _username = '';
  static String _password = '';

  static String get username => _username;
  static String get password => _password;

  static bool get hasCredentials => _username.isNotEmpty && _password.isNotEmpty;

  static Future<void> load() async {
    try {
      _username = (await _storage.read(key: _usernameKey)) ?? '';
      _password = (await _storage.read(key: _passwordKey)) ?? '';
    } catch (error) {
      print('[Config] Failed to load credentials: $error');
    }
  }

  static Future<bool> save(String username, String password) async {
    try {
      final trimmedUsername = username.trim();
      final trimmedPassword = password.trim();
      await _storage.write(key: _usernameKey, value: trimmedUsername);
      await _storage.write(key: _passwordKey, value: trimmedPassword);
      _username = trimmedUsername;
      _password = trimmedPassword;
      return true;
    } catch (error) {
      print('[Config] Failed to save credentials: $error');
      return false;
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.deleteAll();
      _username = '';
      _password = '';
    } catch (error) {
      print('[Config] Failed to clear credentials: $error');
    }
  }
}
