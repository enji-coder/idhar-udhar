import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_constants.dart';
import '../data/mock/mock_models.dart';

/// Local persistence for dummy auth session.
///
/// Swap this implementation later for a real token/session backend without
/// changing UI or navigation call sites.
class SessionStorage {
  SessionStorage();

  static const String _authKey = '${AppConstants.prefsPrefix}auth_v1';
  static const String _knownNamesKey = '${AppConstants.prefsPrefix}known_names_v1';
  static const String _knownEmailsKey =
      '${AppConstants.prefsPrefix}known_emails_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<PersistedSession?> loadSession() async {
    final SharedPreferences prefs = await _prefs;
    final String? raw = prefs.getString(_authKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final bool authenticated = decoded['authenticated'] == true;
      if (!authenticated) {
        return null;
      }
      final String id = (decoded['id'] as String?)?.trim() ?? '';
      final String phone = (decoded['phone'] as String?)?.trim() ?? '';
      if (id.isEmpty || phone.isEmpty) {
        return null;
      }
      return PersistedSession(
        user: MockUser(
          id: id,
          phone: phone,
          name: (decoded['name'] as String?)?.trim() ?? '',
          email: (decoded['email'] as String?)?.trim() ?? '',
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(MockUser user) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(
      _authKey,
      jsonEncode(<String, dynamic>{
        'authenticated': true,
        'id': user.id,
        'phone': user.phone,
        'name': user.name,
        'email': user.email,
      }),
    );
  }

  Future<void> clearSession() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove(_authKey);
  }

  Future<Map<String, String>> loadKnownNames() async {
    return _loadStringMap(_knownNamesKey);
  }

  Future<Map<String, String>> loadKnownEmails() async {
    return _loadStringMap(_knownEmailsKey);
  }

  Future<void> saveKnownNames(Map<String, String> values) async {
    await _saveStringMap(_knownNamesKey, values);
  }

  Future<void> saveKnownEmails(Map<String, String> values) async {
    await _saveStringMap(_knownEmailsKey, values);
  }

  Future<Map<String, String>> _loadStringMap(String key) async {
    final SharedPreferences prefs = await _prefs;
    final String? raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, String>{};
      }
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _saveStringMap(String key, Map<String, String> values) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(key, jsonEncode(values));
  }
}

class PersistedSession {
  const PersistedSession({required this.user});

  final MockUser user;
}
