import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/format/inr_format.dart';
import 'package:idhar_udhar/shared/format/trip_distance.dart';

import '../data/models/rider_order.dart';

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

/// What the incoming screen should show after one offer-list response.
class IncomingOfferChoice {
  const IncomingOfferChoice({
    this.offer,
    this.unavailable = false,
    this.loadFailed = false,
  });

  final RiderOffer? offer;
  final bool unavailable;
  final bool loadFailed;
}

bool _offerStillPending(RiderOffer offer, DateTime now) {
  if (offer.status != 'PENDING') {
    return false;
  }
  final DateTime? expiresAt = offer.expiresAt;
  return expiresAt == null || expiresAt.isAfter(now);
}

RiderOffer? _firstActionableOffer(List<RiderOffer> offers, DateTime now) {
  for (final RiderOffer candidate in offers) {
    if (_offerStillPending(candidate, now)) {
      return candidate;
    }
  }
  return null;
}

/// Chooses the offer the rider can open.
///
/// A targeted id that is present and no longer pending stays unavailable.
/// A targeted id that is absent does not hide a different still-pending offer.
/// A failed list request is not treated as expiry.
IncomingOfferChoice chooseIncomingOffer({
  required List<RiderOffer> offers,
  required String? targetId,
  required bool listLoaded,
  required DateTime now,
}) {
  if (!listLoaded) {
    return const IncomingOfferChoice(loadFailed: true);
  }
  final String id = (targetId ?? '').trim();
  if (id.isNotEmpty) {
    final RiderOffer? targeted = riderOfferById(offers, id);
    if (targeted != null) {
      if (targeted.status != 'PENDING') {
        return const IncomingOfferChoice(unavailable: true);
      }
      return IncomingOfferChoice(offer: targeted);
    }
  }
  final RiderOffer? live = _firstActionableOffer(offers, now);
  if (live != null) {
    return IncomingOfferChoice(offer: live);
  }
  if (id.isNotEmpty) {
    return const IncomingOfferChoice(unavailable: true);
  }
  return const IncomingOfferChoice();
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

/// Whole seconds until [expiresAt]. Null when the server did not send an expiry,
/// so the UI does not invent a 30-second countdown.
int? offerSecondsRemaining(DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) {
    return null;
  }
  final int seconds = expiresAt.difference(now).inSeconds;
  if (seconds <= 0) {
    return 0;
  }
  if (seconds > 86400) {
    return 86400;
  }
  return seconds;
}

/// Tray text for one offer. Missing fare, distance, or addresses are omitted.
/// Nothing is invented. An empty payload uses the generic waiting line.
String riderOfferNotificationBody(Map<String, String> data) {
  final String pickup = (data['pickup_address'] ?? '').trim();
  final String drop = (data['drop_address'] ?? '').trim();
  final double? km = double.tryParse(data['distance_km'] ?? '');
  final int seconds = int.tryParse(data['estimated_duration_seconds'] ?? '') ?? 0;
  final String? fare = _fareLabel(data['trip_fare']);
  final List<String> lines = <String>[
    if (pickup.isNotEmpty) 'Pickup: $pickup',
    if (drop.isNotEmpty) 'Drop: $drop',
    if (km != null) 'Distance: ${formatTripDistanceKm(km)}',
    if (seconds > 0) 'Time: ${_minutesLabel(seconds)}',
    if (fare != null) 'Trip fare: $fare',
  ];
  if (lines.isEmpty) {
    final String body = (data['body'] ?? '').trim();
    return body.isEmpty ? 'A new delivery request is waiting.' : body;
  }
  return lines.join('\n');
}

String? _fareLabel(String? raw) {
  final double? amount = double.tryParse((raw ?? '').trim());
  if (amount == null || amount <= 0) {
    return null;
  }
  return formatInr(amount);
}

String _minutesLabel(int seconds) {
  final int minutes = (seconds / 60).ceil();
  return RiderOrder(
    id: '',
    pickup: '',
    drop: '',
    distanceKm: 0,
    estimatedEarnings: 0,
    estimatedMinutes: minutes,
    customerMaskedName: '',
    customerMaskedPhone: '',
  ).etaLabel;
}

/// Locality and city parsed from a stored stop address.
///
/// Booking addresses are a comma-separated Google line, sometimes prefixed
/// with a house or building. The popup shows only the area and the city.
class OfferAreaCity {
  const OfferAreaCity({required this.area, required this.city});

  final String area;
  final String city;
}

OfferAreaCity offerAreaCity(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty || _isCoordinatePair(trimmed)) {
    return const OfferAreaCity(area: '', city: '');
  }
  final List<String> kept = <String>[];
  for (final String part in trimmed.split(RegExp(r'[,|]'))) {
    final String token = _stripPin(part);
    if (token.isEmpty || _isAddressNoise(token)) {
      continue;
    }
    kept.add(token);
  }
  if (kept.isEmpty) {
    return const OfferAreaCity(area: '', city: '');
  }
  if (kept.length == 1) {
    return OfferAreaCity(area: kept.single, city: '');
  }
  return OfferAreaCity(
    area: kept[kept.length - 2],
    city: kept.last,
  );
}

const Set<String> _addressAdmin = <String>{
  'india',
  'bharat',
  'andhra pradesh',
  'arunachal pradesh',
  'assam',
  'bihar',
  'chhattisgarh',
  'goa',
  'gujarat',
  'haryana',
  'himachal pradesh',
  'jharkhand',
  'karnataka',
  'kerala',
  'madhya pradesh',
  'maharashtra',
  'manipur',
  'meghalaya',
  'mizoram',
  'nagaland',
  'odisha',
  'orissa',
  'punjab',
  'rajasthan',
  'sikkim',
  'tamil nadu',
  'telangana',
  'tripura',
  'uttar pradesh',
  'uttarakhand',
  'west bengal',
  'delhi',
  'nct of delhi',
  'jammu and kashmir',
  'ladakh',
  'lakshadweep',
  'andaman and nicobar islands',
  'dadra and nagar haveli',
  'daman and diu',
  'dadra and nagar haveli and daman and diu',
};

final RegExp _pinCode = RegExp(r'\b\d{5,6}\b');
final RegExp _plusCode = RegExp(
  r'^[23456789cfghjmpqrvwx]{4,}\+[23456789cfghjmpqrvwx]{2,}$',
  caseSensitive: false,
);
final RegExp _houseToken = RegExp(r'^(\d+[a-zA-Z]?|[a-zA-Z]-?\d+[a-zA-Z]?)$');
final RegExp _coordinateToken = RegExp(r'^-?\d{1,3}\.\d+$');
final RegExp _coordinatePair = RegExp(
  r'^-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+$',
);

String _stripPin(String token) {
  return token
      .replaceAll(_pinCode, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isCoordinatePair(String value) => _coordinatePair.hasMatch(value);

bool _isAddressNoise(String token) {
  final String key = token.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (key.length < 2) {
    return true;
  }
  if (_addressAdmin.contains(key) || key == 'unnamed road') {
    return true;
  }
  if (_plusCode.hasMatch(token) || _coordinateToken.hasMatch(token)) {
    return true;
  }
  return _houseToken.hasMatch(token);
}

/// Why a data message cannot be shown. Null means the payload is displayable.
String? offerAlertSkipReason({
  required String? offerId,
  required String? expiresAtRaw,
  required DateTime now,
}) {
  if ((offerId ?? '').trim().isEmpty) {
    return 'missing_offer_id';
  }
  final DateTime? expiresAt = DateTime.tryParse((expiresAtRaw ?? '').trim());
  if (offerNotificationWindow(expiresAt, now).expired) {
    return 'already_expired';
  }
  return null;
}

/// Prefer full-screen intent whenever the platform allows it.
///
/// Overlay-gated activity bring-forward can still fail (OEM background-start
/// limits, process importance quirks). Keeping FSI enabled is a parallel path
/// to the in-app offer UI — not a floating SYSTEM_ALERT_WINDOW overlay.
/// [willBringActivityForward] is retained for callers/logging only.
bool riderOfferPostsFullScreenIntent({
  required bool willBringActivityForward,
  required bool platformAllowsFullScreenIntent,
}) {
  return platformAllowsFullScreenIntent;
}

/// Why a posted offer must not bring the Rider activity forward.
/// Null means the notification was posted and the last saved session may show it.
/// A missing login or availability flag fails closed.
String? riderOfferActivityLaunchSkipReason({
  required bool notificationPosted,
  required bool loggedIn,
  required bool online,
}) {
  if (!notificationPosted) {
    return 'notification_not_posted';
  }
  if (!loggedIn) {
    return 'signed_out';
  }
  if (!online) {
    return 'not_online';
  }
  return null;
}

/// Foreground FCM opens the centered dialog. A notification tap, or a message
/// handled while the app is not resumed, opens the incoming-order screen.
bool riderOfferUsesForegroundDialog({
  required bool openedFromNotification,
  required bool appResumed,
}) {
  return appResumed && !openedFromNotification;
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
    receiverName: active.receiverName,
    receiverPhone: active.receiverPhone,
  );
}
