import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/core/state/trip_online_payment.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/waiting_charge_checkout.dart';
import 'package:idhar_udhar/shared/api/api_config.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';
import 'package:uuid/uuid.dart';

/// City for create/quote/preview. Prefers `--dart-define=IU_CITY_ID`, else
/// the launch city returned by `GET /v1/vehicle-categories`.
Future<String> resolveBookingCityId(
  Future<List<VehicleCategory>> Function() ensureCatalogLoaded,
) async {
  final String defined = ApiConfig.cityId.trim();
  if (defined.isNotEmpty) {
    return defined;
  }
  try {
    await ensureCatalogLoaded();
  } catch (_) {
    // Catalog may already have cached launchCityId from an earlier load.
  }
  return VehicleCategoryCatalog.launchCityId?.trim() ?? '';
}

class BackendQuoteHold {
  const BackendQuoteHold({
    required this.orderId,
    required this.quote,
    required this.vehicleCategoryId,
    required this.bookingKey,
  });

  final String orderId;
  final ApiQuote quote;
  final String vehicleCategoryId;

  /// Vehicle plus pickup/drop coordinates and route distance.
  final String bookingKey;
}

final backendQuoteHoldProvider =
    StateProvider<BackendQuoteHold?>((ref) => null);

/// Shown once on the searching screen. Null for cash-only and failed plans.
final tripOnlinePaymentNoticeProvider =
    StateProvider<TripOnlinePaymentNotice?>((ref) => null);

final orderServerViewProvider =
    FutureProvider.autoDispose.family<ApiOrder, String>((ref, String orderId) {
  return ref.watch(ordersApiProvider).getById(orderId);
});

/// Booking fares from POST /v1/orders/vehicle-fares, keyed by category id.
/// Empty when the route or city is not ready. Waiting is not part of these amounts.
///
/// Watches only the route geometry key so parcel weight/notes/quote updates do
/// not cancel an in-flight vehicle-fares request (that left Parcel Details on "—").
final vehicleFarePreviewProvider =
    FutureProvider.autoDispose<Map<String, String>>((Ref ref) async {
  final String routeKey = ref.watch(
    bookingDraftProvider.select((BookingDraft draft) {
      if (!draft.hasRouteForCurrentStops) {
        return '';
      }
      return draft.currentRouteKey;
    }),
  );
  if (routeKey.isEmpty) {
    return const <String, String>{};
  }
  final BookingDraft draft = ref.read(bookingDraftProvider);
  final String cityId = await resolveBookingCityId(
    () => ref.read(vehicleCategoryCatalogProvider.future),
  );
  if (cityId.isEmpty) {
    throw const ApiException(
      code: 'CITY_INVALID',
      message:
          'Delivery city is not configured. Set IU_CITY_ID or ensure the vehicle catalog returns launch_city_id.',
    );
  }
  final MockLocation? pickup = draft.pickup;
  final double? pickupLat = pickup?.latitude;
  final double? pickupLng = pickup?.longitude;
  if (pickup == null || pickupLat == null || pickupLng == null) {
    return const <String, String>{};
  }
  final List<ApiStop> stops = <ApiStop>[
    ApiStop(
      sequence: 0,
      stopType: 'PICKUP',
      addressText: draft.pickupAddressText.isEmpty
          ? (pickup.address.isEmpty ? pickup.label : pickup.address)
          : draft.pickupAddressText,
      latitude: pickupLat,
      longitude: pickupLng,
    ),
  ];
  final List<MockLocation> drops = draft.allDrops;
  for (int i = 0; i < drops.length; i++) {
    final MockLocation drop = drops[i];
    if (drop.latitude == null || drop.longitude == null) {
      return const <String, String>{};
    }
    stops.add(
      ApiStop(
        sequence: i + 1,
        stopType: 'DROP',
        addressText: draft.locationAddress(drop),
        latitude: drop.latitude!,
        longitude: drop.longitude!,
        contactName: draft.hasReceiver ? draft.receiverName.trim() : null,
        contactPhone: draft.hasReceiver ? draft.receiverMobile.trim() : null,
      ),
    );
  }
  if (ApiConfig.enableRequestLogging) {
    debugPrint(
      'FARE DEBUG provider cityId=$cityId routeKey=$routeKey '
      'pickup=${pickupLat},${pickupLng} drops=${drops.length} '
      'iuCityIdDefine=${ApiConfig.cityId}',
    );
  }
  try {
    return await ref.read(ordersApiProvider).previewVehicleFares(
          cityId: cityId,
          stops: stops,
        );
  } catch (error, stack) {
    if (ApiConfig.enableRequestLogging) {
      debugPrint('FARE DEBUG provider exception=$error');
      debugPrint('FARE DEBUG provider stack=$stack');
    }
    rethrow;
  }
});

List<ApiStop> buildBookingStops(BookingDraft draft) {
  final MockLocation pickup = draft.pickup!;
  final List<ApiStop> stops = <ApiStop>[
    ApiStop(
      sequence: 0,
      stopType: 'PICKUP',
      addressText: draft.pickupAddressText.isEmpty
          ? (pickup.address.isEmpty ? pickup.label : pickup.address)
          : draft.pickupAddressText,
      latitude: pickup.latitude!,
      longitude: pickup.longitude!,
    ),
  ];
  final List<MockLocation> drops = draft.allDrops;
  for (int i = 0; i < drops.length; i++) {
    final MockLocation drop = drops[i];
    stops.add(
      ApiStop(
        sequence: i + 1,
        stopType: 'DROP',
        addressText: draft.locationAddress(drop),
        latitude: drop.latitude!,
        longitude: drop.longitude!,
        contactName: draft.receiverName.trim(),
        contactPhone: draft.receiverMobile.trim(),
      ),
    );
  }
  return stops;
}

Future<BackendQuoteHold> ensureCustomerQuote(WidgetRef ref) async {
  final BookingDraft draft = ref.read(bookingDraftProvider);
  final String? vehicleCategoryId = draft.vehicle?.id;
  if (vehicleCategoryId == null || vehicleCategoryId.isEmpty) {
    throw const ApiException(
      code: 'VALIDATION_ERROR',
      message: 'Select a vehicle category before booking.',
    );
  }
  if (!draft.hasReceiver) {
    throw const ApiException(
      code: 'VALIDATION_ERROR',
      message: 'Receiver name and mobile are required before booking.',
    );
  }
  final BackendQuoteHold? existing = ref.read(backendQuoteHoldProvider);
  if (existing != null &&
      existing.vehicleCategoryId == vehicleCategoryId &&
      existing.bookingKey == draft.quoteBookingKey) {
    return existing;
  }
  final String cityId = await resolveBookingCityId(
    () => ref.read(vehicleCategoryCatalogProvider.future),
  );
  if (cityId.isEmpty) {
    throw const ApiException(
      code: 'CITY_INVALID',
      message:
          'Delivery city is not configured for this build. Set IU_CITY_ID.',
    );
  }
  final String? blocked = draft.incompleteStopMessage;
  if (blocked != null) {
    throw ApiException(code: 'INVALID_STOPS', message: blocked);
  }
  final MockLocation pickup = draft.pickup!;
  if (pickup.latitude == null || pickup.longitude == null) {
    throw const ApiException(
      code: 'INVALID_COORDINATES',
      message: 'Pickup needs a map pin before booking.',
    );
  }
  for (final MockLocation drop in draft.allDrops) {
    if (drop.latitude == null || drop.longitude == null) {
      throw const ApiException(
        code: 'INVALID_COORDINATES',
        message: 'Each drop needs a map pin before booking.',
      );
    }
  }
  final List<ApiStop> stops = buildBookingStops(draft);
  final OrdersApi api = ref.read(ordersApiProvider);
  final ApiOrder created = await api.create(
    cityId: cityId,
    vehicleCategoryId: vehicleCategoryId,
    stops: stops,
    packageWeightKg: draft.weightKg,
    packageSizeCm: draft.selectedParcelSizeCm,
    idempotencyKey: const Uuid().v4(),
  );
  final ApiQuote quote = await api.quote(created.orderId);
  final BackendQuoteHold hold = BackendQuoteHold(
    orderId: created.orderId,
    quote: quote,
    vehicleCategoryId: vehicleCategoryId,
    bookingKey: draft.quoteBookingKey,
  );
  ref.read(backendQuoteHoldProvider.notifier).state = hold;
  ref.read(bookingDraftProvider.notifier).applyQuotedPayable(quote.netPayable);
  return hold;
}

Future<MockOrder> confirmCustomerBooking(WidgetRef ref) async {
  final BookingDraft draft = ref.read(bookingDraftProvider);
  if (!draft.hasReceiver) {
    throw const ApiException(
      code: 'VALIDATION_ERROR',
      message: 'Receiver name and mobile are required before booking.',
    );
  }
  final BackendQuoteHold hold = await ensureCustomerQuote(ref);
  final OrdersApi api = ref.read(ordersApiProvider);
  final ApiOrder confirmed = await api.confirm(
    orderId: hold.orderId,
    fareQuoteId: hold.quote.fareQuoteId,
  );
  // Persist payment responsibility/plan after fare snapshot exists.
  // Confirm has already moved the order to SEARCHING.
  final bool planSaved = await _persistPaymentPlan(api, confirmed.orderId, draft);
  final TripOnlinePaymentOutcome? online = planSaved
      ? await _startTripOnlineCheckout(api, confirmed.orderId, draft)
      : null;
  ref.read(tripOnlinePaymentNoticeProvider.notifier).state =
      tripOnlinePaymentNotice(online);
  final MockOrder mapped = OrderMapper.toMockOrder(
    ApiOrder(
      orderId: confirmed.orderId,
      displayId: confirmed.displayId.isEmpty
          ? hold.quote.displayId
          : confirmed.displayId,
      canonicalStatus: confirmed.canonicalStatus,
      createdAt: confirmed.createdAt,
      cityCode: confirmed.cityCode,
      vehicleCategoryName: confirmed.vehicleCategoryName,
      vehicleCategoryId: confirmed.vehicleCategoryId,
      riderProfileId: confirmed.riderProfileId,
      stops: confirmed.stops,
      tripFare: hold.quote.tripFare,
      distanceKm: hold.quote.distanceKm,
      fareQuoteId: hold.quote.fareQuoteId,
    ),
    vehicle: draft.vehicle,
  );
  ref.read(bookingDraftProvider.notifier).attachActive(mapped);
  return mapped;
}

String _inr(double value) => value.toStringAsFixed(2);

Future<bool> _persistPaymentPlan(
  OrdersApi api,
  String orderId,
  BookingDraft draft,
) async {
  final String whoPays = switch (draft.whoPays) {
    PaymentWhoPays.customer => 'CUSTOMER',
    PaymentWhoPays.receiver => 'RECEIVER',
    PaymentWhoPays.split => 'SPLIT',
  };
  final PaymentAllocation allocation = draft.paymentAllocation;
  try {
    await api.setPaymentResponsibility(
      orderId: orderId,
      whoPays: whoPays,
      customerResponsibility: _inr(draft.customerResponsibility),
      receiverResponsibility: _inr(draft.receiverResponsibility),
    );
    await api.setPaymentPlan(
      orderId: orderId,
      customerPlannedOnline: _inr(allocation.customerOnline),
      customerPlannedCash: _inr(allocation.customerCash),
      receiverPlannedOnline: _inr(allocation.receiverOnline),
      receiverPlannedCash: _inr(allocation.receiverCash),
    );
    return true;
  } on ApiException catch (error) {
    // Confirm already succeeded and SEARCHING/dispatch may be live.
    // Do not roll back the booking UX; ops can repair the payment plan.
    if (ApiConfig.enableRequestLogging) {
      debugPrint(
        'PAYMENT PLAN persist failed after confirm for $orderId '
        'code=${error.code} message=${error.message}',
      );
    }
    return false;
  }
}

/// Opens Cashfree only for a saved ONLINE plan amount.
/// Checkout ending does not mark the trip paid.
Future<TripOnlinePaymentOutcome?> _startTripOnlineCheckout(
  OrdersApi api,
  String orderId,
  BookingDraft draft,
) async {
  final PaymentAllocation allocation = draft.paymentAllocation;
  final List<TripOnlineLeg> legs = tripOnlineLegs(
    customerOnline: allocation.customerOnline,
    customerResponsibility: draft.customerResponsibility,
    receiverOnline: allocation.receiverOnline,
    receiverResponsibility: draft.receiverResponsibility,
  );
  if (legs.isEmpty) {
    return null;
  }
  var sessionMissing = false;
  var checkoutCancelled = false;
  var checkoutEnded = false;
  var anyPaid = false;
  var anyUnpaid = false;
  for (final TripOnlineLeg leg in legs) {
    final OnlineTripTransaction session;
    try {
      session = await api.createOnlineTripTransaction(
        orderId: orderId,
        payerType: leg.payerType,
        amount: leg.amount,
        idempotencyKey: tripOnlineIdempotencyKey(
          payerType: leg.payerType,
          amount: leg.amount,
        ),
      );
    } on ApiException catch (error) {
      sessionMissing = true;
      if (ApiConfig.enableRequestLogging) {
        debugPrint(
          'TRIP ONLINE charge failed for $orderId '
          'payer=${leg.payerType} code=${error.code} message=${error.message}',
        );
      }
      break;
    }
    if (!session.canOpenCheckout) {
      sessionMissing = true;
      break;
    }
    try {
      await openTripFareCheckout(
        paymentSessionId: session.paymentSessionId,
        cashfreeOrderId: session.cashfreeOrderId,
        environment: session.environment,
      );
      checkoutEnded = true;
    } on ApiException catch (error) {
      if (error.code == 'PAYMENT_PROVIDER_UNAVAILABLE') {
        sessionMissing = true;
        break;
      }
      checkoutCancelled = true;
    }
    final String? status = await _readTripTransactionStatus(
      api,
      orderId,
      session.paymentTransactionId,
    );
    if (status == 'PAID') {
      anyPaid = true;
    } else {
      anyUnpaid = true;
    }
    if (checkoutCancelled || sessionMissing) {
      break;
    }
  }
  return TripOnlinePaymentOutcome(
    serverPaid: anyPaid && !anyUnpaid && !sessionMissing,
    sessionMissing: sessionMissing,
    checkoutCancelled: checkoutCancelled,
    checkoutEnded: checkoutEnded,
  );
}

Future<String?> _readTripTransactionStatus(
  OrdersApi api,
  String orderId,
  String paymentTransactionId,
) async {
  try {
    final OnlineTripPaymentStatus refreshed = await api.verifyOnlineTripTransaction(
      orderId: orderId,
      paymentTransactionId: paymentTransactionId,
    );
    return refreshed.transactionStatus;
  } on ApiException catch (error) {
    if (ApiConfig.enableRequestLogging) {
      debugPrint(
        'TRIP ONLINE status refresh failed for $orderId '
        'code=${error.code} message=${error.message}',
      );
    }
    return null;
  }
}
