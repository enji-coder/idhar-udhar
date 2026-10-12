import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';

/// One Accept or Reject tap from an incoming-offer notification.
class RiderOfferUserAction {
  const RiderOfferUserAction({
    required this.id,
    required this.offerId,
    required this.action,
  });

  final int id;
  final String offerId;
  final String action;
}

/// Keeps a single unconsumed notification action.
/// A repeated launch callback for that same tap is ignored.
class RiderOfferActionGate {
  RiderOfferUserAction? pending;
  String? _consumedKey;
  int _nextId = 0;

  RiderOfferUserAction? note(String? offerId, String? action) {
    final String id = (offerId ?? '').trim();
    final String act = (action ?? '').trim();
    if (id.isEmpty || (act != 'accept' && act != 'reject')) {
      return null;
    }
    final String key = '$id|$act';
    final RiderOfferUserAction? current = pending;
    if (current != null && current.offerId == id && current.action == act) {
      return null;
    }
    if (_consumedKey == key) {
      return null;
    }
    final RiderOfferUserAction next = RiderOfferUserAction(
      id: ++_nextId,
      offerId: id,
      action: act,
    );
    pending = next;
    return next;
  }

  void consume(RiderOfferUserAction action) {
    _consumedKey = '${action.offerId}|${action.action}';
    if (pending?.id == action.id) {
      pending = null;
    }
  }
}

/// The notification's offer, or null when that id is not in the list.
/// A targeted action never falls through to a different pending offer.
RiderOffer? riderOfferById(List<RiderOffer> offers, String? offerId) {
  final String id = (offerId ?? '').trim();
  if (id.isEmpty) {
    return null;
  }
  for (final RiderOffer offer in offers) {
    if (offer.offerId == id) {
      return offer;
    }
  }
  return null;
}

/// Remaining time for Android `timeoutAfter`, measured at post time.
class OfferNotificationWindow {
  const OfferNotificationWindow({required this.expired, this.timeoutAfterMs});

  final bool expired;
  final int? timeoutAfterMs;
}

const int _maxNotificationTimeoutMs = 2147483647;

OfferNotificationWindow offerNotificationWindow(DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) {
    return const OfferNotificationWindow(expired: false);
  }
  final int remaining = expiresAt.difference(now).inMilliseconds;
  if (remaining <= 0) {
    return const OfferNotificationWindow(expired: true, timeoutAfterMs: 0);
  }
  return OfferNotificationWindow(
    expired: false,
    timeoutAfterMs:
        remaining > _maxNotificationTimeoutMs ? _maxNotificationTimeoutMs : remaining,
  );
}

/// Accepted-order offer state. Server fare and distance win when present.
/// Duration stays on the offer that was shown, because order fetch has no duration.
RiderOffer acceptedOfferState({
  required RiderOffer active,
  ApiOrder? order,
}) {
  final String fetchedOrderId = (order?.orderId ?? '').trim();
  return RiderOffer(
    offerId: active.offerId,
    orderId: fetchedOrderId.isNotEmpty ? fetchedOrderId : active.orderId,
    status: 'ACCEPTED',
    createdAt: active.createdAt,
    displayId: active.displayId,
    crn: order?.crn ?? active.crn,
    orderStatus: order?.canonicalStatus ?? active.orderStatus,
    tripFare: order?.tripFare ?? active.tripFare,
    riderAmount: order?.riderAmount ?? active.riderAmount,
    distanceKm: order?.distanceKm ?? active.distanceKm,
    estimatedDurationSeconds: active.estimatedDurationSeconds,
    expiresAt: active.expiresAt,
    vehicleCategoryName: active.vehicleCategoryName ?? order?.vehicleCategoryName,
    packageWeightKg: active.packageWeightKg ?? order?.packageWeightKg,
    pickupAddress: active.pickupAddress ?? order?.pickupAddress,
    dropAddress: active.dropAddress ?? order?.dropAddress,
    pickupLatitude: active.pickupLatitude,
    pickupLongitude: active.pickupLongitude,
    dropLatitude: active.dropLatitude,
    dropLongitude: active.dropLongitude,
  );
}
