import 'package:shared_preferences/shared_preferences.dart';

/// Rider-only local flags. Isolated from Customer session keys.
abstract final class RiderPrefs {
  static const String _setupKey = 'rider_initial_setup_complete_v1';
  static const String _termsKey = 'rider_terms_accepted_v1';
  static const String loggedInKey = 'rider_logged_in_v1';
  static const String _onlineKey = 'rider_online_v1';

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

  /// Reloads disk state. Required in the FCM background isolate so online /
  /// login flags written by the UI isolate are visible before launch gates.
  static Future<SharedPreferences> _prefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await _prefs();
    return prefs.getBool(loggedInKey) ?? false;
  }

  static Future<void> setLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(loggedInKey, true);
  }

  /// Last online value stored from the server profile or availability call.
  /// Missing or false means the background offer launch must not run.
  static Future<bool> isOnline() async {
    final prefs = await _prefs();
    return prefs.getBool(_onlineKey) ?? false;
  }

  static Future<void> setOnline(bool online) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlineKey, online);
  }

  /// Explicit Logout only — do not call on splash, close, or permission deny.
  static Future<void> clearLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(loggedInKey, false);
    await prefs.setBool(_onlineKey, false);
  }
}
