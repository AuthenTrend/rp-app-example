
import 'package:flutter_passkey/flutter_passkey.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Config {

  static const String _keyRpHostName = "_keyRpHostName";
  static const String _keyPasskeyEnabled = "_keyPasskeyEnabled";

  static Future<bool> get isPasskeySupported async {
    return FlutterPasskey().isSupported();
  }

  static Future<bool> get isPasskeyEnabled async {
    var isEnabled = false;
    final isSupported = await isPasskeySupported;
    if (isSupported) {
      final pref = await SharedPreferences.getInstance();
      isEnabled = pref.getBool(_keyPasskeyEnabled) ?? true;
    }
    return isEnabled;
  }

  static void setPasskeyEnabled(bool enabled) async {
    final isSupported = await isPasskeySupported;
    if (isSupported) {
      final pref = await SharedPreferences.getInstance();
      await pref.setBool(_keyPasskeyEnabled, enabled);
    }
  }

  static Future<void> save(String key, String value) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(key, value);
  }

  static Future<String?> load(String key) async {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(key);
  }

  static Future<void> remove(String key) async {
    final pref = await SharedPreferences.getInstance();
    await pref.remove(key);
  }

}
