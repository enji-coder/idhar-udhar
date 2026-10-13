import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native Online presence foreground service (Android Rider).
///
/// Dart [Timer]s freeze when the app is backgrounded. While Online, this
/// service posts GPS / heartbeat under the server presence window and shows an
/// ongoing notification. Stopped when the rider goes Offline or logs out.
class RiderOnlinePresence {
  RiderOnlinePresence._();

  static const MethodChannel _channel = MethodChannel(
    'com.idharudhar.rider/presence',
  );

  static Future<void> start({
    required String accessToken,
    required String baseUrl,
  }) async {
    if (!_isAndroid) {
      return;
    }
    final String token = accessToken.trim();
    final String base = baseUrl.trim();
    if (token.isEmpty || base.isEmpty) {
      return;
    }
    try {
      final bool? started = await _channel.invokeMethod<bool>(
        'startOnlinePresence',
        <String, String>{
          'accessToken': token,
          'baseUrl': base,
        },
      );
      if (started != true) {
        debugPrint(
          'rider_online_presence_not_started reason=native_declined',
        );
      }
    } on MissingPluginException {
      // Customer flavor / desktop — no FGS plugin.
    } catch (error, stack) {
      debugPrint('rider_online_presence_start_failed $error\n$stack');
    }
  }

  static Future<void> updateAuth({
    required String accessToken,
    required String baseUrl,
  }) async {
    if (!_isAndroid) {
      return;
    }
    final String token = accessToken.trim();
    final String base = baseUrl.trim();
    if (token.isEmpty || base.isEmpty) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(
        'updateOnlinePresenceAuth',
        <String, String>{
          'accessToken': token,
          'baseUrl': base,
        },
      );
    } on MissingPluginException {
      // ignore
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('stopOnlinePresence');
    } on MissingPluginException {
      // ignore
    } catch (_) {}
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
