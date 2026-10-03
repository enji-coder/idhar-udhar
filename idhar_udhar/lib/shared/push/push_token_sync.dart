import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../api/device_tokens_api.dart';

/// Syncs an FCM device token with Nest `POST /v1/device-tokens`.
///
/// Production delivery still requires Firebase (`firebase_messaging` +
/// `firebase_options.dart` / google-services). Until FlutterFire is configured,
/// pass a real token via `--dart-define=IU_FCM_TOKEN=...` for staging checks.
/// Never invents a token or reports fake send success.
class PushTokenSync {
  PushTokenSync(this._api);

  final DeviceTokensApi _api;
  String? _registeredToken;

  static const String _definedToken = String.fromEnvironment('IU_FCM_TOKEN');

  Future<void> syncAfterAuth() async {
    final String token = _definedToken.trim();
    if (token.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'PUSH: no FCM token available (configure Firebase or IU_FCM_TOKEN)',
        );
      }
      return;
    }
    final String platform = _platformLabel();
    await _api.register(token: token, platform: platform);
    _registeredToken = token;
  }

  Future<void> unregisterOnLogout() async {
    final String token = (_registeredToken ?? _definedToken).trim();
    if (token.isEmpty) {
      return;
    }
    try {
      await _api.unregister(token);
    } catch (_) {
      // Logout must proceed even if unregister fails.
    }
    _registeredToken = null;
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'WEB';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.android:
        return 'ANDROID';
      default:
        return 'ANDROID';
    }
  }
}

final pushTokenSyncProvider = Provider<PushTokenSync>((ref) {
  return PushTokenSync(ref.watch(deviceTokensApiProvider));
});
