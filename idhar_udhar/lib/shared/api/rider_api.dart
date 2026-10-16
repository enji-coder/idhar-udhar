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
    final List<Map<String, Object?>> rows =
        jsonList(json['ratings']).map(jsonObject).toList(growable: false);
    String? comment;
    for (final Map<String, Object?> row in rows) {
      final String? text = jsonString(row['comment']);
      if (text != null && text.trim().isNotEmpty) {
        comment = text.trim();
        break;
      }
    }
    return RiderRatingSummary(
      count: json['rating_count'] is num
          ? (json['rating_count'] as num).toInt()
          : 0,
      average: json['rating_average'] == null
          ? 0
          : jsonDouble(json['rating_average']),
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
    this.tripFare,
    this.riderAmount,
    this.distanceKm,
    this.estimatedDurationSeconds,
    this.expiresAt,
    this.vehicleCategoryName,
    this.packageWeightKg,
    this.pickupAddress,
    this.dropAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropLatitude,
    this.dropLongitude,
    this.receiverName,
    this.receiverPhone,
  });

  final String offerId;
  final String orderId;
  final String status;
  final DateTime createdAt;
  final String? displayId;
  final String? crn;
  final String? orderStatus;
  final double? tripFare;
  final double? riderAmount;
  final double? distanceKm;
  final int? estimatedDurationSeconds;
  final DateTime? expiresAt;
  final String? vehicleCategoryName;
  final double? packageWeightKg;
  final String? pickupAddress;
  final String? dropAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropLatitude;
  final double? dropLongitude;
  final String? receiverName;
  final String? receiverPhone;

  factory RiderOffer.fromJson(Map<String, Object?> json) {
    return RiderOffer(
      offerId: jsonString(json['order_offer_id']) ?? '',
      orderId: jsonString(json['order_id']) ?? '',
      status: jsonString(json['status']) ?? 'PENDING',
      createdAt: jsonDate(json['created_at']) ?? DateTime.now(),
      displayId: jsonString(json['display_id']),
      crn: jsonString(json['crn']),
      orderStatus: jsonString(json['order_status']),
      tripFare:
          json['trip_fare'] == null ? null : jsonDouble(json['trip_fare']),
      riderAmount: json['rider_amount'] == null
          ? null
          : jsonDouble(json['rider_amount']),
      distanceKm:
          json['distance_km'] == null ? null : jsonDouble(json['distance_km']),
      estimatedDurationSeconds: json['estimated_duration_seconds'] == null
          ? null
          : jsonInt(json['estimated_duration_seconds']),
      expiresAt: jsonDate(json['expires_at']),
      vehicleCategoryName: jsonString(json['vehicle_category_name']),
      packageWeightKg: json['package_weight_kg'] == null
          ? null
          : jsonDouble(json['package_weight_kg']),
      pickupAddress: jsonString(json['pickup_address']),
      dropAddress: jsonString(json['drop_address']),
      pickupLatitude: json['pickup_latitude'] == null
          ? null
          : jsonDouble(json['pickup_latitude']),
      pickupLongitude: json['pickup_longitude'] == null
          ? null
          : jsonDouble(json['pickup_longitude']),
      dropLatitude: json['drop_latitude'] == null
          ? null
          : jsonDouble(json['drop_latitude']),
      dropLongitude: json['drop_longitude'] == null
          ? null
          : jsonDouble(json['drop_longitude']),
      receiverName: jsonString(json['receiver_name']),
      receiverPhone: jsonString(json['receiver_phone']),
    );
  }
}

class PickupWaitSnapshot {
  const PickupWaitSnapshot({
    required this.arrivalAt,
    required this.pickedUpAt,
    required this.serverNow,
    required this.timestampStatus,
    required this.initialWaitingMinutes,
    required this.perMinute,
    required this.elapsedSeconds,
    required this.elapsedMinutes,
    required this.chargeableMinutes,
    required this.amount,
    required this.amountSource,
    required this.vehicleCategoryName,
    this.hasWaitingRules = true,
    this.hasWaitingRate = true,
  });

  final DateTime? arrivalAt;
  final DateTime? pickedUpAt;
  final DateTime serverNow;
  final String timestampStatus;
  final int initialWaitingMinutes;
  final String perMinute;
  final int? elapsedSeconds;
  final int elapsedMinutes;
  final int chargeableMinutes;
  final String amount;
  final String amountSource;
  final String vehicleCategoryName;

  /// False when the payload omitted the snapshotted free-waiting minutes.
  final bool hasWaitingRules;

  /// False when the snapshot rate is missing or not a rupee amount.
  /// An explicit zero from the server stays true.
  final bool hasWaitingRate;

  factory PickupWaitSnapshot.fromJson(Map<String, Object?> json) {
    final int? minutes = _waitingMinutes(json['initial_waiting_minutes']);
    final String? rate = _waitingRate(json['waiting_charge_per_minute']);
    return PickupWaitSnapshot(
      arrivalAt: _time(json['arrival_at']),
      pickedUpAt: _time(json['picked_up_at']),
      serverNow: _time(json['server_now']) ?? DateTime.now().toUtc(),
      timestampStatus:
          jsonString(json['timestamp_status']) ?? 'missing_arrival',
      initialWaitingMinutes: minutes ?? 0,
      hasWaitingRules: minutes != null,
      hasWaitingRate: rate != null,
      perMinute: rate ?? '',
      elapsedSeconds: _waitingMinutes(json['elapsed_seconds']),
      elapsedMinutes: _waitingMinutes(json['elapsed_minutes']) ?? 0,
      chargeableMinutes: _waitingMinutes(json['chargeable_minutes']) ?? 0,
      amount: jsonString(json['amount']) ?? '0.00',
      amountSource: jsonString(json['amount_source']) ?? 'preview',
      vehicleCategoryName: jsonString(json['vehicle_category_name']) ?? '',
    );
  }

  bool get arrivalMissing => timestampStatus != 'ok' || arrivalAt == null;
}

int? _waitingMinutes(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite) {
    return value.toInt();
  }
  if (value is String) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }
  return null;
}

String? _waitingRate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    if (!value.isFinite || value < 0) {
      return null;
    }
    return value.toStringAsFixed(2);
  }
  final String? text = jsonString(value)?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  final RegExpMatch? match =
      RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) {
    return null;
  }
  final String frac = (match.group(2) ?? '').padRight(2, '0');
  return '${match.group(1)}.$frac';
}

DateTime? _time(Object? value) {
  final String? text = jsonString(value);
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text)?.toUtc();
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
    return ApiOrder.fromJson(
      jsonObject(body['order']).isEmpty ? body : jsonObject(body['order']),
    );
  }

  Future<void> rejectOffer(String offerId) async {
    await _client.post('/v1/rider/offers/$offerId/reject');
  }

  Future<ApiOrder> getOrder(String orderId) async {
    return ApiOrder.fromJson(await _client.get('/v1/rider/orders/$orderId'));
  }

  Future<PickupWaitSnapshot> getPickupWait(String orderId) async {
    return PickupWaitSnapshot.fromJson(
      await _client.get('/v1/rider/orders/$orderId/pickup-wait'),
    );
  }

  /// Existing payment view. Null when the body has no usable allocation.
  /// HTTP failures propagate and must not be stored as a zero-cash order.
  Future<ApiOrderPaymentView?> getOrderPayment(String orderId) async {
    final ApiOrderPaymentView? view = ApiOrderPaymentView.tryParse(
      await _client.get('/v1/orders/$orderId/payment'),
    );
    if (view == null || view.orderId != orderId) {
      return null;
    }
    return view;
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

  /// Touches server last_seen while Online when GPS cannot be read.
  Future<void> postPresenceHeartbeat() async {
    await _client.post('/v1/rider/presence/heartbeat');
  }

  Future<Map<String, Object?>> getLocation() {
    return _client.get('/v1/rider/location');
  }
}
