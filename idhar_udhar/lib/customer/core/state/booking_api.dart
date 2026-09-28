import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/core/state/vehicle_fare.dart';
import 'package:idhar_udhar/shared/api/api_config.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:uuid/uuid.dart';

class BackendQuoteHold {
  const BackendQuoteHold({
    required this.orderId,
    required this.quote,
    required this.vehicleCategoryId,
    required this.routeKey,
    required this.packageWeightKg,
  });

  final String orderId;
  final ApiQuote quote;
  final String vehicleCategoryId;
  final String routeKey;
  final double packageWeightKg;
}

bool quoteHoldMatches(BookingDraft draft, BackendQuoteHold? hold) {
  if (hold == null) {
    return false;
  }
  final String? routeKey = draft.fareRouteKey;
  if (routeKey == null || hold.routeKey != routeKey) {
    return false;
  }
  if (hold.vehicleCategoryId != draft.vehicle?.id) {
    return false;
  }
  return (hold.packageWeightKg - draft.weightKg).abs() < 0.001;
}

List<ApiStop> stopsForDraft(BookingDraft draft) {
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
      ),
    );
  }
  return stops;
}

final vehicleFarePreviewProvider =
    FutureProvider.autoDispose<VehicleFarePreview>((ref) async {
  final String routeKey = ref.watch(
    bookingDraftProvider.select(
      (BookingDraft draft) => draft.fareRouteKey ?? '',
    ),
  );
  if (routeKey.isEmpty) {
    throw const ApiException(
      code: 'INVALID_STOPS',
      message: 'Confirm pickup and drop before choosing a vehicle.',
    );
  }
  if (ApiConfig.cityId.trim().isEmpty) {
    throw const ApiException(
      code: 'CITY_INVALID',
      message: 'Delivery city is not configured for this build. Set IU_CITY_ID.',
    );
  }
  final BookingDraft draft = ref.read(bookingDraftProvider);
  final Map<String, Object?> body =
      await ref.read(ordersApiProvider).previewVehicleFares(
            cityId: ApiConfig.cityId,
            stops: stopsForDraft(draft),
          );
  return VehicleFarePreview.parse(body);
});

final backendQuoteHoldProvider =
    StateProvider<BackendQuoteHold?>((ref) => null);

Future<BackendQuoteHold> ensureCustomerQuote(WidgetRef ref) async {
  final BookingDraft draft = ref.read(bookingDraftProvider);
  final String? vehicleCategoryId = draft.vehicle?.id;
  if (vehicleCategoryId == null || vehicleCategoryId.isEmpty) {
    throw const ApiException(
      code: 'VALIDATION_ERROR',
      message: 'Select a vehicle category before booking.',
    );
  }
  final BackendQuoteHold? existing = ref.read(backendQuoteHoldProvider);
  if (quoteHoldMatches(draft, existing)) {
    return existing!;
  }
  final String? routeKey = draft.fareRouteKey;
  if (routeKey == null) {
    throw const ApiException(
      code: 'INVALID_STOPS',
      message: 'Confirm pickup and drop before booking.',
    );
  }
  if (ApiConfig.cityId.trim().isEmpty) {
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
  final List<MockLocation> drops = draft.allDrops;
  for (final MockLocation drop in drops) {
    if (drop.latitude == null || drop.longitude == null) {
      throw const ApiException(
        code: 'INVALID_COORDINATES',
        message: 'Each drop needs a map pin before booking.',
      );
    }
  }
  final OrdersApi api = ref.read(ordersApiProvider);
  final ApiOrder created = await api.create(
    cityId: ApiConfig.cityId,
    vehicleCategoryId: vehicleCategoryId,
    stops: stopsForDraft(draft),
    packageWeightKg: draft.weightKg,
    idempotencyKey: const Uuid().v4(),
  );
  final ApiQuote quote = await api.quote(created.orderId);
  final BackendQuoteHold hold = BackendQuoteHold(
    orderId: created.orderId,
    quote: quote,
    vehicleCategoryId: vehicleCategoryId,
    routeKey: routeKey,
    packageWeightKg: draft.weightKg,
  );
  ref.read(backendQuoteHoldProvider.notifier).state = hold;
  ref.read(bookingDraftProvider.notifier).applyQuotedPayable(quote.netPayable);
  return hold;
}

Future<MockOrder> confirmCustomerBooking(WidgetRef ref) async {
  final BackendQuoteHold hold = await ensureCustomerQuote(ref);
  final OrdersApi api = ref.read(ordersApiProvider);
  final ApiOrder confirmed = await api.confirm(
    orderId: hold.orderId,
    fareQuoteId: hold.quote.fareQuoteId,
  );
  final BookingDraft draft = ref.read(bookingDraftProvider);
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
