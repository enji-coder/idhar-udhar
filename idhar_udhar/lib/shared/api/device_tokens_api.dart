import 'api_client.dart';

/// Registers FCM tokens with the existing Nest device-token API.
///
/// Push delivery requires a real FCM token from firebase_messaging (or equivalent).
/// This client never invents tokens.
class DeviceTokensApi {
  DeviceTokensApi(this._client);

  final ApiClient _client;

  Future<void> register({
    required String token,
    required String platform,
    String? appInstanceId,
  }) async {
    final String trimmed = token.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('FCM token is required');
    }
    await _client.post(
      '/v1/device-tokens',
      data: <String, Object?>{
        'token': trimmed,
        'platform': platform,
        if (appInstanceId != null && appInstanceId.isNotEmpty)
          'app_instance_id': appInstanceId,
      },
    );
  }

  Future<void> unregister(String token) async {
    final String trimmed = token.trim();
    if (trimmed.isEmpty) return;
    await _client.post(
      '/v1/device-tokens/unregister',
      data: <String, Object?>{'token': trimmed},
    );
  }
}
