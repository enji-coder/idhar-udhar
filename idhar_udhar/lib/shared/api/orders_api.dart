import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'api_exception.dart';
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
    this.riderAmount,
    this.distanceKm,
    this.fareQuoteId,
    this.waitingAmount,
    this.receivableOutstanding,
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
  final double? riderAmount;
  final double? distanceKm;
  final String? fareQuoteId;

  /// Server pickup-waiting assessment. Null until the backend has assessed it.
  final double? waitingAmount;

  /// Outstanding post-booking receivable from the server ledger.
  final double? receivableOutstanding;

  factory ApiOrder.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> snapshot = jsonObject(json['fare_snapshot']);
    final Map<String, Object?> waiting = jsonObject(json['waiting']);
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
      riderAmount: json['rider_amount'] == null
          ? null
          : jsonDouble(json['rider_amount']),
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
      waitingAmount: waiting['amount'] == null
          ? null
          : jsonDouble(waiting['amount']),
      receivableOutstanding: waiting['outstanding_amount'] == null
          ? null
          : jsonDouble(waiting['outstanding_amount']),
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

class ReceivableClearance {
  const ReceivableClearance({
    required this.paymentTransactionId,
    required this.amount,
    required this.paymentSessionId,
    required this.cashfreeOrderId,
    required this.environment,
  });

  final String paymentTransactionId;
  final String amount;
  final String paymentSessionId;
  final String cashfreeOrderId;
  final String environment;

  factory ReceivableClearance.fromJson(Map<String, Object?> json) {
    return ReceivableClearance(
      paymentTransactionId: jsonString(json['payment_transaction_id']) ?? '',
      amount: jsonString(json['amount']) ?? '',
      paymentSessionId: jsonString(json['payment_session_id']) ?? '',
      cashfreeOrderId: jsonString(json['cashfree_order_id']) ?? '',
      environment: jsonString(json['cashfree_environment']) ?? '',
    );
  }

  /// Checkout can open only when Cashfree returned a session for this charge.
  bool get canOpenCheckout =>
      paymentSessionId.isNotEmpty &&
      cashfreeOrderId.isNotEmpty &&
      (environment == 'sandbox' || environment == 'production');
}

class OrdersApi {
  OrdersApi(this._client);

  final ApiClient _client;
  final Uuid _uuid = const Uuid();

  Future<ApiOrder> create({
    required String cityId,
    required String vehicleCategoryId,
    required List<ApiStop> stops,
    double? packageWeightKg,
    double? packageSizeCm,
    String? idempotencyKey,
  }) async {
    final Map<String, Object?> body = await _client.post(
      '/v1/orders',
      data: <String, Object?>{
        'city_id': cityId,
        'vehicle_category_id': vehicleCategoryId,
        'stops': stops.map((ApiStop stop) => stop.toJson()).toList(),
        if (packageWeightKg != null) 'package_weight_kg': packageWeightKg,
        if (packageSizeCm != null) 'package_size_cm': packageSizeCm,
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

  /// Starts a Cashfree charge for the server-calculated waiting receivable.
  /// The amount is not sent by the app. Checkout success is not payment success.
  Future<ReceivableClearance> startReceivableClearance(String orderId) async {
    final Map<String, Object?> body = await _client.post(
      '/v1/orders/$orderId/receivable-clearance',
      data: <String, Object?>{},
      headers: <String, String>{'Idempotency-Key': _uuid.v4()},
    );
    return ReceivableClearance.fromJson(body);
  }

  Future<List<ApiStop>> listStops(String orderId) async {
    final Map<String, Object?> body =
        await _client.get('/v1/orders/$orderId/stops');
    return jsonList(body['stops'])
        .map((Object? item) => ApiStop.fromJson(jsonObject(item)))
        .toList(growable: false);
  }

  /// Server prices every active category for these stops. Amounts in the
  /// response are the booking fare. Waiting is not included.
  Future<Map<String, String>> previewVehicleFares({
    required String cityId,
    required List<ApiStop> stops,
  }) async {
    // ignore: avoid_print — temporary IU_FARE_PREVIEW diagnostics
    debugPrint(
      '[IU_FARE_PREVIEW] POST /v1/orders/vehicle-fares attempted '
      'cityId=$cityId stopCount=${stops.length}',
    );
    try {
      final Map<String, Object?> body = await _client.post(
        '/v1/orders/vehicle-fares',
        data: <String, Object?>{
          'city_id': cityId,
          'stops': stops.map((ApiStop stop) => stop.toJson()).toList(),
        },
      );
      final Object? vehiclesRaw = body['vehicles'];
      final List<Object?> vehicles = jsonList(vehiclesRaw);
      debugPrint(
        '[IU_FARE_PREVIEW] POST ok vehiclesType=${vehiclesRaw.runtimeType} '
        'vehiclesLen=${vehicles.length}',
      );
      final Map<String, String> fares = <String, String>{};
      for (final Object? item in vehicles) {
        final Map<String, Object?> vehicle = jsonObject(item);
        final String? id = jsonString(vehicle['vehicle_category_id']);
        final Map<String, Object?> fare = jsonObject(vehicle['fare']);
        final String? payable = jsonString(fare['net_payable']);
        debugPrint(
          '[IU_FARE_PREVIEW] response vehicle id=$id '
          'net_payable=$payable fareKeys=${fare.keys.toList()}',
        );
        if (id != null &&
            id.isNotEmpty &&
            payable != null &&
            payable.isNotEmpty) {
          fares[id] = payable;
        }
      }
      debugPrint(
        '[IU_FARE_PREVIEW] parsed fare map keys=${fares.keys.toList()} '
        'values=${fares.values.toList()}',
      );
      return fares;
    } on ApiException catch (error) {
      debugPrint(
        '[IU_FARE_PREVIEW] POST failed status=${error.statusCode} '
        'code=${error.code} message=${error.message}',
      );
      rethrow;
    } catch (error) {
      debugPrint('[IU_FARE_PREVIEW] POST failed error=$error');
      rethrow;
    }
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
