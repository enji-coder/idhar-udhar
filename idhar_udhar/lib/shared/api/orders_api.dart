import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'json_codec.dart';

class ApiStop {
  const ApiStop({
    required this.sequence,
    required this.stopType,
    required this.addressText,
    required this.latitude,
    required this.longitude,
    this.contactName,
    this.contactPhone,
  });

  final int sequence;
  final String stopType;
  final String addressText;
  final double latitude;
  final double longitude;
  final String? contactName;
  final String? contactPhone;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sequence': sequence,
      'stop_type': stopType,
      'address_text': addressText,
      'latitude': latitude,
      'longitude': longitude,
      if (contactName != null) 'contact_name': contactName,
      if (contactPhone != null) 'contact_phone': contactPhone,
    };
  }

  factory ApiStop.fromJson(Map<String, Object?> json) {
    return ApiStop(
      sequence: jsonInt(json['sequence']),
      stopType: jsonString(json['stop_type']) ?? 'DROP',
      addressText: jsonString(json['address_text']) ?? '',
      latitude: jsonDouble(json['latitude']),
      longitude: jsonDouble(json['longitude']),
      contactName: jsonString(json['contact_name']),
      contactPhone: jsonString(json['contact_phone']),
    );
  }
}

class ApiOrder {
  const ApiOrder({
    required this.orderId,
    required this.displayId,
    required this.canonicalStatus,
    required this.createdAt,
    this.cityCode,
    this.vehicleCategoryName,
    this.vehicleCategoryId,
    this.riderProfileId,
    this.stops = const <ApiStop>[],
    this.tripFare,
    this.distanceKm,
    this.fareQuoteId,
  });

  final String orderId;
  final String displayId;
  final String canonicalStatus;
  final DateTime createdAt;
  final String? cityCode;
  final String? vehicleCategoryName;
  final String? vehicleCategoryId;
  final String? riderProfileId;
  final List<ApiStop> stops;
  final double? tripFare;
  final double? distanceKm;
  final String? fareQuoteId;

  factory ApiOrder.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> snapshot = jsonObject(json['fare_snapshot']);
    final Map<String, Object?> quote = json.containsKey('fare_quote_id')
        ? json
        : jsonObject(json['fare_quote']);
    return ApiOrder(
      orderId: jsonString(json['order_id']) ?? '',
      displayId: jsonString(json['display_id']) ?? '',
      canonicalStatus: jsonString(json['canonical_status']) ?? 'CREATED',
      createdAt: jsonDate(json['created_at']) ?? DateTime.now(),
      cityCode: jsonString(json['city_code']),
      vehicleCategoryName: jsonString(json['vehicle_category_name']),
      vehicleCategoryId: jsonString(json['vehicle_category_id']),
      riderProfileId: jsonString(json['rider_profile_id']),
      stops: jsonList(json['stops'])
          .map((Object? item) => ApiStop.fromJson(jsonObject(item)))
          .toList(growable: false),
      tripFare: json['trip_fare'] != null
          ? jsonDouble(json['trip_fare'])
          : (snapshot['trip_fare'] != null
              ? jsonDouble(snapshot['trip_fare'])
              : (quote['trip_fare'] != null
                  ? jsonDouble(quote['trip_fare'])
                  : null)),
      distanceKm: json['distance_km'] != null
          ? jsonDouble(json['distance_km'])
          : (snapshot['distance_km'] != null
              ? jsonDouble(snapshot['distance_km'])
              : null),
      fareQuoteId: jsonString(json['fare_quote_id']) ??
          jsonString(quote['fare_quote_id']),
    );
  }
}

class ApiQuote {
  const ApiQuote({
    required this.orderId,
    required this.displayId,
    required this.fareQuoteId,
    required this.tripFare,
    required this.netPayable,
    required this.distanceKm,
    this.baseFare = 0,
    this.distanceCharge = 0,
    this.discount = 0,
    this.waiting = 0,
  });

  final String orderId;
  final String displayId;
  final String fareQuoteId;
  final double tripFare;
  final double netPayable;
  final double distanceKm;
  final double baseFare;
  final double distanceCharge;
  final double discount;
  final double waiting;

  factory ApiQuote.fromJson(Map<String, Object?> json) {
    return ApiQuote(
      orderId: jsonString(json['order_id']) ?? '',
      displayId: jsonString(json['display_id']) ?? '',
      fareQuoteId: jsonString(json['fare_quote_id']) ?? '',
      tripFare: jsonDouble(json['trip_fare']),
      netPayable: jsonDouble(json['net_payable']),
      distanceKm: jsonDouble(json['distance_km']),
      baseFare: jsonDouble(json['base_fare']),
      distanceCharge: jsonDouble(json['distance_charge']),
      discount: jsonDouble(json['discount']),
      waiting: jsonDouble(json['waiting']),
    );
  }
}

class OrdersApi {
  OrdersApi(this._client);

  final ApiClient _client;
  final Uuid _uuid = const Uuid();

  Future<ApiOrder> create({
    required String cityId,
    required String vehicleCategoryId,
    required List<ApiStop> stops,
    String? idempotencyKey,
  }) async {
    final Map<String, Object?> body = await _client.post(
      '/v1/orders',
      data: <String, Object?>{
        'city_id': cityId,
        'vehicle_category_id': vehicleCategoryId,
        'stops': stops.map((ApiStop stop) => stop.toJson()).toList(),
      },
      headers: <String, String>{
        'Idempotency-Key': idempotencyKey ?? _uuid.v4(),
      },
    );
    return ApiOrder.fromJson(body);
  }

  Future<List<ApiOrder>> list() async {
    final Map<String, Object?> body = await _client.get('/v1/orders');
    return jsonList(body['orders'])
        .map((Object? item) => ApiOrder.fromJson(jsonObject(item)))
        .toList(growable: false);
  }

  Future<ApiOrder> getById(String orderId) async {
    return ApiOrder.fromJson(await _client.get('/v1/orders/$orderId'));
  }

  Future<List<ApiStop>> listStops(String orderId) async {
    final Map<String, Object?> body =
        await _client.get('/v1/orders/$orderId/stops');
    return jsonList(body['stops'])
        .map((Object? item) => ApiStop.fromJson(jsonObject(item)))
        .toList(growable: false);
  }

  Future<ApiQuote> quote(String orderId) async {
    return ApiQuote.fromJson(
      await _client.post('/v1/orders/$orderId/quote', data: <String, Object?>{}),
    );
  }

  Future<ApiOrder> confirm({
    required String orderId,
    required String fareQuoteId,
  }) async {
    return ApiOrder.fromJson(
      await _client.post(
        '/v1/orders/$orderId/confirm',
        data: <String, String>{'fare_quote_id': fareQuoteId},
      ),
    );
  }

  Future<ApiOrder> cancel(String orderId) async {
    return ApiOrder.fromJson(
      await _client.post('/v1/orders/$orderId/cancel'),
    );
  }
}
