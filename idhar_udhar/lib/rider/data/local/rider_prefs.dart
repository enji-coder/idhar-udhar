import 'package:shared_preferences/shared_preferences.dart';

/// Rider-only local flags. Isolated from Customer session keys.
abstract final class RiderPrefs {
  static const String _setupKey = 'rider_initial_setup_complete_v1';
  static const String _termsKey = 'rider_terms_accepted_v1';
  static const String loggedInKey = 'rider_logged_in_v1';

  static Future<bool> isInitialSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupKey) ?? false;
  }

  static Future<void> setInitialSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupKey, true);
  }

  static Future<bool> isTermsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_termsKey) ?? false;
  }

  static Future<void> setTermsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_termsKey, true);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(loggedInKey) ?? false;
  }

  static Future<void> setLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(loggedInKey, true);
  }

  /// Explicit Logout only — do not call on splash, close, or permission deny.
  static Future<void> clearLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(loggedInKey, false);
  }
}
