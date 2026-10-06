import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'json_codec.dart';

class ApiFareSnapshot {
  const ApiFareSnapshot({
    this.baseFare = 0,
    this.distanceCharge = 0,
    this.waiting = 0,
    this.surge = 0,
    this.toll = 0,
    this.parking = 0,
    this.discount = 0,
    this.tripFare = 0,
    this.netPayable = 0,
  });

  final double baseFare;
  final double distanceCharge;
  final double waiting;
  final double surge;
  final double toll;
  final double parking;
  final double discount;
  final double tripFare;
  final double netPayable;

  factory ApiFareSnapshot.fromJson(Map<String, Object?> json) {
    return ApiFareSnapshot(
      baseFare: jsonDouble(json['base_fare']),
      distanceCharge: jsonDouble(json['distance_charge']),
      waiting: jsonDouble(json['waiting']),
      surge: jsonDouble(json['surge']),
      toll: jsonDouble(json['toll']),
      parking: jsonDouble(json['parking']),
      discount: jsonDouble(json['discount']),
      tripFare: jsonDouble(json['trip_fare']),
      netPayable: jsonDouble(json['net_payable']),
    );
  }
}

class ApiCustomerRating {
  const ApiCustomerRating({
    required this.stars,
    this.comment,
    this.createdAt,
  });

  final int stars;
  final String? comment;
  final DateTime? createdAt;

  factory ApiCustomerRating.fromJson(Map<String, Object?> json) {
    return ApiCustomerRating(
      stars: json['stars'] is num ? (json['stars'] as num).toInt() : 0,
      comment: jsonString(json['comment']),
      createdAt: jsonDate(json['created_at']),
    );
  }
}

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

  /// Nest `CreateOrderStopDto` allows at most 6 fractional digits
  /// (`@IsNumber({ maxDecimalPlaces: 6 })`). Raw GPS doubles often exceed that
  /// and fail `POST /v1/orders/vehicle-fares` with HTTP 400.
  static double coordinateForApi(double value) {
    return double.parse(value.toStringAsFixed(6));
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sequence': sequence,
      'stop_type': stopType,
      'address_text': addressText,
      'latitude': coordinateForApi(latitude),
      'longitude': coordinateForApi(longitude),
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

class ApiAssignedRider {
  const ApiAssignedRider({
    this.name,
    this.vehicleRegistration,
    this.vehicleCategoryName,
    this.phone,
  });

  final String? name;
  final String? vehicleRegistration;
  final String? vehicleCategoryName;
  final String? phone;

  factory ApiAssignedRider.fromJson(Map<String, Object?> json) {
    return ApiAssignedRider(
      name: jsonString(json['name']),
      vehicleRegistration: jsonString(json['vehicle_registration']),
      vehicleCategoryName: jsonString(json['vehicle_category_name']),
      phone: jsonString(json['phone']),
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
    this.assignedRider,
    this.stops = const <ApiStop>[],
    this.tripFare,
    this.riderAmount,
    this.distanceKm,
    this.fareQuoteId,
    this.crn,
    this.pickupAddress,
    this.dropAddress,
    this.netPayable,
    this.packageWeightKg,
    this.fareSnapshot,
    this.customerRating,
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
  final ApiAssignedRider? assignedRider;
  final List<ApiStop> stops;
  final double? tripFare;
  final double? riderAmount;
  final double? distanceKm;
  final String? fareQuoteId;
  final String? crn;
  final String? pickupAddress;
  final String? dropAddress;
  final double? netPayable;
  final double? packageWeightKg;
  final ApiFareSnapshot? fareSnapshot;
  final ApiCustomerRating? customerRating;

  /// Server pickup-waiting assessment. Null until the backend has assessed it.
  final double? waitingAmount;

  /// Outstanding post-booking receivable from the server ledger.
  final double? receivableOutstanding;

  factory ApiOrder.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> snapshot = jsonObject(json['fare_snapshot']);
    final Map<String, Object?> waiting = jsonObject(json['waiting']);
    final Map<String, Object?> assigned = jsonObject(json['assigned_rider']);
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
      assignedRider: assigned.isEmpty ? null : ApiAssignedRider.fromJson(assigned),
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
      crn: jsonString(json['crn']),
      pickupAddress: jsonString(json['pickup_address']),
      dropAddress: jsonString(json['drop_address']),
      netPayable: json['net_payable'] != null
          ? jsonDouble(json['net_payable'])
          : (snapshot['net_payable'] != null
              ? jsonDouble(snapshot['net_payable'])
              : null),
      packageWeightKg: json['package_weight_kg'] == null
          ? null
          : jsonDouble(json['package_weight_kg']),
      fareSnapshot:
          snapshot.isEmpty ? null : ApiFareSnapshot.fromJson(snapshot),
      customerRating: json['customer_rating'] is Map
          ? ApiCustomerRating.fromJson(jsonObject(json['customer_rating']))
          : null,
      waitingAmount:
          waiting['amount'] == null ? null : jsonDouble(waiting['amount']),
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

class OnlineTripTransaction {
  const OnlineTripTransaction({
    required this.paymentTransactionId,
    required this.amount,
    required this.transactionStatus,
    required this.paymentSessionId,
    required this.cashfreeOrderId,
    required this.environment,
  });

  final String paymentTransactionId;
  final String amount;
  final String transactionStatus;
  final String paymentSessionId;
  final String cashfreeOrderId;
  final String environment;

  factory OnlineTripTransaction.fromJson(Map<String, Object?> json) {
    return OnlineTripTransaction(
      paymentTransactionId: jsonString(json['payment_transaction_id']) ?? '',
      amount: jsonString(json['amount']) ?? '',
      transactionStatus: jsonString(json['transaction_status']) ?? '',
      paymentSessionId: jsonString(json['payment_session_id']) ?? '',
      cashfreeOrderId: jsonString(json['cashfree_order_id']) ?? '',
      environment: jsonString(json['cashfree_environment']) ?? '',
    );
  }

  /// Checkout needs a transaction id for the later status read, plus a session.
  bool get canOpenCheckout =>
      paymentTransactionId.isNotEmpty &&
      paymentSessionId.isNotEmpty &&
      cashfreeOrderId.isNotEmpty &&
      (environment == 'sandbox' || environment == 'production');
}

class OnlineTripPaymentStatus {
  const OnlineTripPaymentStatus({
    required this.paymentTransactionId,
    required this.transactionStatus,
    required this.authoritative,
  });

  final String paymentTransactionId;

  /// Database status. PAID only after the Cashfree webhook settles the row.
  final String transactionStatus;

  /// The verify endpoint is a refresh. It does not settle the charge.
  final bool authoritative;

  factory OnlineTripPaymentStatus.fromJson(Map<String, Object?> json) {
    return OnlineTripPaymentStatus(
      paymentTransactionId: jsonString(json['payment_transaction_id']) ?? '',
      transactionStatus: jsonString(json['transaction_status']) ?? '',
      authoritative: json['authoritative'] == true,
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

  /// Resolves one shipment. CRN is unique, so this returns that order only.
  Future<ApiOrder> getByCrn(String crn) async {
    return ApiOrder.fromJson(
      await _client.get('/v1/orders/crn/${Uri.encodeComponent(crn)}'),
    );
  }

  Future<ApiCustomerRating> rateOrder({
    required String orderId,
    required int stars,
    String? comment,
  }) async {
    final Map<String, Object?> body = await _client.post(
      '/v1/orders/$orderId/rating',
      data: <String, Object?>{
        'stars': stars,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
    return ApiCustomerRating.fromJson(body);
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
    final List<Map<String, Object?>> stopPayload =
        stops.map((ApiStop stop) => stop.toJson()).toList(growable: false);
    final Map<String, Object?> request = <String, Object?>{
      'city_id': cityId,
      'stops': stopPayload,
    };
    if (ApiConfig.enableRequestLogging) {
      debugPrint(
        'FARE DEBUG request path=/v1/orders/vehicle-fares '
        'baseUrl=${ApiConfig.baseUrl} cityId=$cityId '
        'stopCount=${stopPayload.length} stops=$stopPayload',
      );
    }
    try {
      final Map<String, Object?> body = await _client.post(
        '/v1/orders/vehicle-fares',
        data: request,
      );
      final Map<String, String> fares = <String, String>{};
      for (final Object? item in jsonList(body['vehicles'])) {
        final Map<String, Object?> vehicle = jsonObject(item);
        final String? id = jsonString(vehicle['vehicle_category_id']);
        final Map<String, Object?> fare = jsonObject(vehicle['fare']);
        final String? payable = jsonString(fare['net_payable']);
        if (id != null &&
            id.isNotEmpty &&
            payable != null &&
            payable.isNotEmpty) {
          fares[id] = payable;
        }
      }
      if (ApiConfig.enableRequestLogging) {
        debugPrint(
          'FARE DEBUG response vehicleCount=${jsonList(body['vehicles']).length} '
          'parsedCount=${fares.length} fares=$fares '
          'distance_km=${body['distance_km']}',
        );
      }
      return fares;
    } on ApiException catch (error, stack) {
      if (ApiConfig.enableRequestLogging) {
        debugPrint(
          'FARE DEBUG exception code=${error.code} status=${error.statusCode} '
          'message=${error.message} details=${error.details}',
        );
        debugPrint('FARE DEBUG stack=$stack');
      }
      rethrow;
    } catch (error, stack) {
      if (ApiConfig.enableRequestLogging) {
        debugPrint('FARE DEBUG exception=$error');
        debugPrint('FARE DEBUG stack=$stack');
      }
      rethrow;
    }
  }

  Future<ApiQuote> quote(String orderId) async {
    return ApiQuote.fromJson(
      await _client
          .post('/v1/orders/$orderId/quote', data: <String, Object?>{}),
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

  /// Records who pays after fare confirm. Does not charge Cashfree.
  Future<void> setPaymentResponsibility({
    required String orderId,
    required String whoPays,
    required String customerResponsibility,
    required String receiverResponsibility,
  }) async {
    await _client.post(
      '/v1/orders/$orderId/payment/responsibility',
      data: <String, Object?>{
        'who_pays': whoPays,
        'customer_responsibility': customerResponsibility,
        'receiver_responsibility': receiverResponsibility,
      },
    );
  }

  /// Creates one ONLINE trip-fare charge. The server keeps it PENDING.
  /// A stable [idempotencyKey] replays the same session on confirm retry.
  Future<OnlineTripTransaction> createOnlineTripTransaction({
    required String orderId,
    required String payerType,
    required String amount,
    required String idempotencyKey,
  }) async {
    final Map<String, Object?> body = await _client.post(
      '/v1/orders/$orderId/payment/transactions',
      data: <String, Object?>{
        'payer_type': payerType,
        'method': 'ONLINE',
        'amount': amount,
        'direction': 'CHARGE',
      },
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
    );
    return OnlineTripTransaction.fromJson(body);
  }

  /// Reads the stored trip transaction. Does not mark it paid.
  Future<OnlineTripPaymentStatus> verifyOnlineTripTransaction({
    required String orderId,
    required String paymentTransactionId,
  }) async {
    final Map<String, Object?> body = await _client.post(
      '/v1/orders/$orderId/payment/transactions/$paymentTransactionId/verify',
      data: <String, Object?>{},
    );
    return OnlineTripPaymentStatus.fromJson(body);
  }

  /// Records online/cash plan after responsibility. Does not charge Cashfree.
  Future<void> setPaymentPlan({
    required String orderId,
    required String customerPlannedOnline,
    required String customerPlannedCash,
    required String receiverPlannedOnline,
    required String receiverPlannedCash,
  }) async {
    await _client.post(
      '/v1/orders/$orderId/payment/plan',
      data: <String, Object?>{
        'customer_planned_online': customerPlannedOnline,
        'customer_planned_cash': customerPlannedCash,
        'receiver_planned_online': receiverPlannedOnline,
        'receiver_planned_cash': receiverPlannedCash,
      },
    );
  }

  /// Latest assigned-rider GPS for an active delivery. Null when unavailable.
  Future<RiderLiveLocation?> riderLocation(String orderId) async {
    final Map<String, Object?> body =
        await _client.get('/v1/orders/$orderId/rider-location');
    final Map<String, Object?>? loc = body['location'] is Map
        ? jsonObject(body['location'])
        : null;
    if (loc == null) {
      return null;
    }
    final double? lat = (loc['latitude'] as num?)?.toDouble();
    final double? lng = (loc['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      return null;
    }
    return RiderLiveLocation(
      latitude: lat,
      longitude: lng,
      stale: body['stale'] == true,
      recordedAt: jsonString(loc['recorded_at']),
    );
  }
}

class RiderLiveLocation {
  const RiderLiveLocation({
    required this.latitude,
    required this.longitude,
    required this.stale,
    this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final bool stale;
  final String? recordedAt;
}
