import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/shared/api/api_config.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';
import 'package:uuid/uuid.dart';

/// Temporary fare-preview diagnostics. Tag: IU_FARE_PREVIEW
void _farePreviewDiag(String message) {
  debugPrint('[IU_FARE_PREVIEW] $message');
}

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

final orderServerViewProvider =
    FutureProvider.autoDispose.family<ApiOrder, String>((ref, String orderId) {
  return ref.watch(ordersApiProvider).getById(orderId);
});

/// Booking fares from POST /v1/orders/vehicle-fares, keyed by category id.
/// Empty when the route or city is not ready. Waiting is not part of these amounts.
final vehicleFarePreviewProvider =
    FutureProvider.autoDispose<Map<String, String>>((Ref ref) async {
  final BookingDraft draft = ref.watch(bookingDraftProvider);
  _farePreviewDiag(
    'provider run hasRoute=${draft.hasRouteForCurrentStops} '
    'routeKm=${draft.routeDistanceKm} '
    'sigMatch=${draft.routeSignature == draft.currentRouteKey}',
  );
  if (!draft.hasRouteForCurrentStops) {
    _farePreviewDiag('early exit: no route for current stops');
    return const <String, String>{};
  }
  final String cityId = await resolveBookingCityId(
    () => ref.read(vehicleCategoryCatalogProvider.future),
  );
  _farePreviewDiag(
    'resolved cityId=${cityId.isEmpty ? "<empty>" : cityId} '
    'launchCityId=${VehicleCategoryCatalog.launchCityId ?? "<null>"}',
  );
  if (cityId.isEmpty) {
    _farePreviewDiag('early exit: empty cityId');
    return const <String, String>{};
  }
  final MockLocation? pickup = draft.pickup;
  final double? pickupLat = pickup?.latitude;
  final double? pickupLng = pickup?.longitude;
  if (pickup == null || pickupLat == null || pickupLng == null) {
    _farePreviewDiag(
      'early exit: pickup coords missing pickupNull=${pickup == null} '
      'lat=$pickupLat lng=$pickupLng',
    );
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
      _farePreviewDiag(
        'early exit: drop[$i] coords missing lat=${drop.latitude} lng=${drop.longitude}',
      );
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
  _farePreviewDiag(
    'calling previewVehicleFares pickup=($pickupLat,$pickupLng) '
    'drops=${drops.map((MockLocation d) => '(${d.latitude},${d.longitude})').join(' ')} '
    'stopCount=${stops.length}',
  );
  try {
    final Map<String, String> fares =
        await ref.read(ordersApiProvider).previewVehicleFares(
              cityId: cityId,
              stops: stops,
            );
    _farePreviewDiag(
      'parsed fare map keys=${fares.keys.toList()} values=${fares.values.toList()}',
    );
    return fares;
  } catch (error) {
    _farePreviewDiag('previewVehicleFares threw: $error');
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
      message: 'Delivery city is not configured for this build. Set IU_CITY_ID.',
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
