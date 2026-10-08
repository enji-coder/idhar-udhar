import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_token_sync.dart';

/// Runtime FCM token source for an already-initialized Firebase app.
class FirebaseFcmTokenSource implements FcmTokenSource {
  FirebaseFcmTokenSource({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<String?> currentToken() => _messaging.getToken();

  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<String> requestNotificationPermission() async {
    final NotificationSettings settings = await _messaging.requestPermission();
    return settings.authorizationStatus.name;
  }
}
