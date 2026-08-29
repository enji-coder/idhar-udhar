import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access + refresh tokens. Never SharedPreferences (not a secret store).
///
/// Keys are namespaced by `--dart-define=IU_APP=customer|rider` so Customer
/// and Rider Chrome sessions cannot overwrite each other if they share an origin.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage, String? namespace})
      : _storage = storage ?? const FlutterSecureStorage(),
        _ns = namespace ?? _appNamespace;

  static const String _appNamespace = String.fromEnvironment(
    'IU_APP',
    defaultValue: 'shared',
  );

  final FlutterSecureStorage _storage;
  final String _ns;

  String get _accessKey => 'iu_${_ns}_access_token';
  String get _refreshKey => 'iu_${_ns}_refresh_token';
  String get _roleKey => 'iu_${_ns}_session_role';
  String get _phoneKey => 'iu_${_ns}_session_phone';

  Future<String?> get accessToken async => _read(_accessKey);

  Future<String?> get refreshToken async => _read(_refreshKey);

  Future<String?> get role async => _read(_roleKey);

  Future<String?> get phone async => _read(_phoneKey);

  Future<bool> get hasRefreshToken async {
    final String? token = await refreshToken;
    return token != null && token.isNotEmpty;
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? role,
    String? phone,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    if (role != null) {
      await _storage.write(key: _roleKey, value: role);
    }
    if (phone != null) {
      await _storage.write(key: _phoneKey, value: phone);
    }
  }

  Future<void> updateAccessToken(String accessToken) async {
    await _storage.write(key: _accessKey, value: accessToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _phoneKey);
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }
}
