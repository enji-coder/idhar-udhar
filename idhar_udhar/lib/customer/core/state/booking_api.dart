import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
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
  });

  final String orderId;
  final ApiQuote quote;
}

final backendQuoteHoldProvider =
    StateProvider<BackendQuoteHold?>((ref) => null);

Future<BackendQuoteHold> ensureCustomerQuote(WidgetRef ref) async {
  final BackendQuoteHold? existing = ref.read(backendQuoteHoldProvider);
  if (existing != null) {
    return existing;
  }
  if (!ApiConfig.hasCatalogIds) {
    throw const ApiException(
      code: 'CITY_INVALID',
      message:
          'Delivery catalog is not configured for this build. Set IU_CITY_ID and IU_VEHICLE_CATEGORY_ID.',
    );
  }
  final BookingDraft draft = ref.read(bookingDraftProvider);
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
  final List<ApiStop> stops = <ApiStop>[
    ApiStop(
      sequence: 0,
      stopType: 'PICKUP',
      addressText: pickup.address.isEmpty ? pickup.label : pickup.address,
      latitude: pickup.latitude!,
      longitude: pickup.longitude!,
    ),
  ];
  final List<MockLocation> drops = draft.allDrops;
  for (int i = 0; i < drops.length; i++) {
    final MockLocation drop = drops[i];
    if (drop.latitude == null || drop.longitude == null) {
      throw const ApiException(
        code: 'INVALID_COORDINATES',
        message: 'Each drop needs a map pin before booking.',
      );
    }
    stops.add(
      ApiStop(
        sequence: i + 1,
        stopType: 'DROP',
        addressText: drop.address.isEmpty ? drop.label : drop.address,
        latitude: drop.latitude!,
        longitude: drop.longitude!,
      ),
    );
  }
  final OrdersApi api = ref.read(ordersApiProvider);
  final ApiOrder created = await api.create(
    cityId: ApiConfig.cityId,
    vehicleCategoryId: ApiConfig.vehicleCategoryId,
    stops: stops,
    idempotencyKey: const Uuid().v4(),
  );
  final ApiQuote quote = await api.quote(created.orderId);
  final BackendQuoteHold hold = BackendQuoteHold(
    orderId: created.orderId,
    quote: quote,
  );
  ref.read(backendQuoteHoldProvider.notifier).state = hold;
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
