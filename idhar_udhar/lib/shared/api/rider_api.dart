import 'api_client.dart';
import 'json_codec.dart';
import 'orders_api.dart';

class RiderRatingSummary {
  const RiderRatingSummary({
    required this.count,
    required this.average,
    this.latestComment,
  });

  final int count;
  final double average;
  final String? latestComment;

  factory RiderRatingSummary.fromJson(Map<String, Object?> json) {
    final List<Map<String, Object?>> rows = jsonList(json['ratings'])
        .map(jsonObject)
        .toList(growable: false);
    String? comment;
    for (final Map<String, Object?> row in rows) {
      final String? text = jsonString(row['comment']);
      if (text != null && text.trim().isNotEmpty) {
        comment = text.trim();
        break;
      }
    }
    return RiderRatingSummary(
      count: json['rating_count'] is num ? (json['rating_count'] as num).toInt() : 0,
      average: json['rating_average'] == null ? 0 : jsonDouble(json['rating_average']),
      latestComment: comment,
    );
  }
}

class RiderOffer {
  const RiderOffer({
    required this.offerId,
    required this.orderId,
    required this.status,
    required this.createdAt,
    this.displayId,
    this.crn,
    this.orderStatus,
    this.riderAmount,
  });

  final String offerId;
  final String orderId;
  final String status;
  final DateTime createdAt;
  final String? displayId;
  final String? crn;
  final String? orderStatus;
  final double? riderAmount;

  factory RiderOffer.fromJson(Map<String, Object?> json) {
    return RiderOffer(
      offerId: jsonString(json['order_offer_id']) ?? '',
      orderId: jsonString(json['order_id']) ?? '',
      status: jsonString(json['status']) ?? 'PENDING',
      createdAt: jsonDate(json['created_at']) ?? DateTime.now(),
      displayId: jsonString(json['display_id']),
      crn: jsonString(json['crn']),
      orderStatus: jsonString(json['order_status']),
      riderAmount: json['rider_amount'] == null
          ? null
          : jsonDouble(json['rider_amount']),
    );
  }
}

class RiderApi {
  RiderApi(this._client);

  final ApiClient _client;

  Future<RiderRatingSummary> ratings() async {
    return RiderRatingSummary.fromJson(await _client.get('/v1/rider/ratings'));
  }

  Future<List<RiderOffer>> listOffers() async {
    final Map<String, Object?> body = await _client.get('/v1/rider/offers');
    return jsonList(body['offers'])
        .map((Object? item) => RiderOffer.fromJson(jsonObject(item)))
        .toList(growable: false);
  }

  Future<ApiOrder> acceptOffer(String offerId) async {
    final Map<String, Object?> body =
        await _client.post('/v1/rider/offers/$offerId/accept');
    return ApiOrder.fromJson(jsonObject(body['order']).isEmpty ? body : jsonObject(body['order']));
  }

  Future<void> rejectOffer(String offerId) async {
    await _client.post('/v1/rider/offers/$offerId/reject');
  }

  Future<ApiOrder> getOrder(String orderId) async {
    return ApiOrder.fromJson(await _client.get('/v1/rider/orders/$orderId'));
  }

  Future<ApiOrder> transitionStatus({
    required String orderId,
    required String toStatus,
    String? reason,
  }) async {
    return ApiOrder.fromJson(
      await _client.post(
        '/v1/rider/orders/$orderId/status',
        data: <String, String>{
          'to_status': toStatus,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      ),
    );
  }

  Future<void> postLocation({
    required double latitude,
    required double longitude,
    DateTime? timestamp,
  }) async {
    await _client.post(
      '/v1/rider/location',
      data: <String, Object?>{
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': (timestamp ?? DateTime.now().toUtc()).toIso8601String(),
      },
    );
  }

  Future<Map<String, Object?>> getLocation() {
    return _client.get('/v1/rider/location');
  }
}
