import 'api_client.dart';
import 'json_codec.dart';

class ApiNotification {
  const ApiNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.orderId,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? orderId;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory ApiNotification.fromJson(Map<String, Object?> json) {
    return ApiNotification(
      id: jsonString(json['notification_id']) ?? '',
      type: jsonString(json['type']) ?? '',
      title: jsonString(json['title']) ?? '',
      body: jsonString(json['body']) ?? '',
      createdAt: jsonDate(json['created_at']) ?? DateTime.now(),
      orderId: jsonString(json['order_id']),
      readAt: jsonDate(json['read_at']),
    );
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.inAppEnabled,
    required this.pushEnabled,
  });

  final bool inAppEnabled;
  final bool pushEnabled;

  factory NotificationPreferences.fromJson(Map<String, Object?> json) {
    return NotificationPreferences(
      inAppEnabled: jsonBool(json['in_app_enabled'], fallback: true),
      pushEnabled: jsonBool(json['push_enabled'], fallback: true),
    );
  }
}

class NotificationsApi {
  NotificationsApi(this._client);

  final ApiClient _client;

  Future<List<ApiNotification>> list({int limit = 50}) async {
    final Map<String, Object?> body = await _client.get(
      '/v1/notifications',
      query: <String, dynamic>{'limit': '$limit'},
    );
    return jsonList(body['notifications'])
        .map((Object? item) => ApiNotification.fromJson(jsonObject(item)))
        .toList(growable: false);
  }

  Future<int> unreadCount() async {
    final Map<String, Object?> body =
        await _client.get('/v1/notifications/unread-count');
    return jsonInt(body['unread_count']);
  }

  Future<ApiNotification> markRead(String id) async {
    return ApiNotification.fromJson(
      await _client.post('/v1/notifications/$id/read'),
    );
  }

  Future<int> markAllRead() async {
    final Map<String, Object?> body =
        await _client.post('/v1/notifications/read-all');
    return jsonInt(body['updated']);
  }

  Future<NotificationPreferences> getPreferences() async {
    return NotificationPreferences.fromJson(
      await _client.get('/v1/notification-preferences'),
    );
  }

  Future<NotificationPreferences> updatePreferences({
    required bool inAppEnabled,
    required bool pushEnabled,
  }) async {
    return NotificationPreferences.fromJson(
      await _client.put(
        '/v1/notification-preferences',
        data: <String, bool>{
          'in_app_enabled': inAppEnabled,
          'push_enabled': pushEnabled,
        },
      ),
    );
  }
}
