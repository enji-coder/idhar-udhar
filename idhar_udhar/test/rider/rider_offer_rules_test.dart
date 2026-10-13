import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/push/rider_offer_rules.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';

void main() {
  test('notification action is delivered once for the tapped offer', () {
    final RiderOfferActionGate gate = RiderOfferActionGate();
    final RiderOfferUserAction? first = gate.note('offer-b', 'accept');
    expect(first?.offerId, 'offer-b');
    expect(first?.action, 'accept');
    expect(gate.note('offer-b', 'accept'), isNull);
    expect(gate.note('open-only', 'open'), isNull);

    gate.consume(first!);
    expect(gate.pending, isNull);
    expect(gate.note('offer-b', 'accept'), isNull);

    final RiderOfferUserAction? reject = gate.note('offer-b', 'reject');
    expect(reject?.action, 'reject');
    expect(gate.note('offer-b', 'reject'), isNull);
  });

  test('a targeted offer id is not replaced by the first pending offer', () {
    final List<RiderOffer> offers = <RiderOffer>[
      _offer('offer-a'),
      _offer('offer-b'),
    ];
    expect(riderOfferById(offers, 'offer-b')?.offerId, 'offer-b');
    expect(riderOfferById(offers, 'missing'), isNull);
  });

  test('notification timeout uses remaining time until expires_at', () {
    final DateTime now = DateTime.utc(2026, 10, 9, 12);
    final DateTime created = now.subtract(const Duration(seconds: 18));
    final DateTime expiresAt = created.add(const Duration(seconds: 30));
    final OfferNotificationWindow window = offerNotificationWindow(expiresAt, now);
    expect(window.expired, isFalse);
    expect(window.timeoutAfterMs, 12000);

    final OfferNotificationWindow expired =
        offerNotificationWindow(now.subtract(const Duration(milliseconds: 1)), now);
    expect(expired.expired, isTrue);
    expect(expired.timeoutAfterMs, 0);

    final OfferNotificationWindow open = offerNotificationWindow(null, now);
    expect(open.expired, isFalse);
    expect(open.timeoutAfterMs, isNull);

    final OfferNotificationWindow clamped = offerNotificationWindow(
      DateTime.utc(9999),
      now,
    );
    expect(clamped.timeoutAfterMs, 2147483647);
  });

  test('countdown follows a 30 second server expiry and does not invent one', () {
    final DateTime now = DateTime.utc(2026, 10, 9, 12);
    expect(
      offerSecondsRemaining(now.add(const Duration(seconds: 30)), now),
      30,
    );
    expect(
      offerSecondsRemaining(now.subtract(const Duration(seconds: 1)), now),
      0,
    );
    expect(offerSecondsRemaining(null, now), isNull);
    expect(
      offerAlertSkipReason(offerId: '', expiresAtRaw: null, now: now),
      'missing_offer_id',
    );
    expect(
      offerAlertSkipReason(
        offerId: 'offer-a',
        expiresAtRaw: now.subtract(const Duration(seconds: 1)).toIso8601String(),
        now: now,
      ),
      'already_expired',
    );
    expect(
      offerAlertSkipReason(
        offerId: 'offer-a',
        expiresAtRaw: now.add(const Duration(seconds: 30)).toIso8601String(),
        now: now,
      ),
      isNull,
    );
  });

  test('full-screen intent stays enabled even when also bringing the activity forward', () {
    expect(
      riderOfferPostsFullScreenIntent(
        willBringActivityForward: true,
        platformAllowsFullScreenIntent: true,
      ),
      isTrue,
    );
    expect(
      riderOfferPostsFullScreenIntent(
        willBringActivityForward: false,
        platformAllowsFullScreenIntent: true,
      ),
      isTrue,
    );
    expect(
      riderOfferPostsFullScreenIntent(
        willBringActivityForward: true,
        platformAllowsFullScreenIntent: false,
      ),
      isFalse,
    );
    expect(
      riderOfferPostsFullScreenIntent(
        willBringActivityForward: false,
        platformAllowsFullScreenIntent: false,
      ),
      isFalse,
    );
  });

  test('activity launch waits for a posted alert and a signed-in online rider', () {
    expect(
      riderOfferActivityLaunchSkipReason(
        notificationPosted: false,
        loggedIn: true,
        online: true,
      ),
      'notification_not_posted',
    );
    expect(
      riderOfferActivityLaunchSkipReason(
        notificationPosted: true,
        loggedIn: false,
        online: true,
      ),
      'signed_out',
    );
    expect(
      riderOfferActivityLaunchSkipReason(
        notificationPosted: true,
        loggedIn: true,
        online: false,
      ),
      'not_online',
    );
    expect(
      riderOfferActivityLaunchSkipReason(
        notificationPosted: true,
        loggedIn: true,
        online: true,
      ),
      isNull,
    );
  });

  test('foreground FCM uses the dialog and a notification tap uses the screen', () {
    expect(
      riderOfferUsesForegroundDialog(
        openedFromNotification: false,
        appResumed: true,
      ),
      isTrue,
    );
    expect(
      riderOfferUsesForegroundDialog(
        openedFromNotification: true,
        appResumed: true,
      ),
      isFalse,
    );
    expect(
      riderOfferUsesForegroundDialog(
        openedFromNotification: false,
        appResumed: false,
      ),
      isFalse,
    );
  });

  test('notification text uses offer fields and omits missing ones', () {
    expect(
      riderOfferNotificationBody(<String, String>{}),
      'A new delivery request is waiting.',
    );
    expect(
      riderOfferNotificationBody(<String, String>{
        'pickup_address': 'CG Road',
        'drop_address': 'Navrangpura',
        'distance_km': '1.3',
        'estimated_duration_seconds': '156',
        'trip_fare': '500',
      }),
      'Pickup: CG Road\nDrop: Navrangpura\nDistance: 1.3 km\nTime: 3 min\nTrip fare: ₹500',
    );
    expect(
      riderOfferNotificationBody(<String, String>{
        'pickup_address': 'CG Road',
        'trip_fare': '0',
        'distance_km': 'not-a-number',
      }),
      'Pickup: CG Road',
    );
  });

  test('accepted order keeps offer duration and prefers server fare and distance', () {
    final RiderOffer active = _offer(
      'offer-a',
      tripFare: 500,
      distanceKm: 12.4,
      estimatedDurationSeconds: 70 * 60,
    );
    final ApiOrder fetched = ApiOrder(
      orderId: active.orderId,
      displayId: 'IU-1',
      canonicalStatus: 'ASSIGNED',
      createdAt: DateTime.utc(2026, 10, 9),
      tripFare: 640,
      distanceKm: 15,
    );
    final RiderOrder order = OrderMapper.toRiderOrder(
      offer: acceptedOfferState(active: active, order: fetched),
      order: fetched,
    );
    expect(order.tripAmount, 640);
    expect(order.distanceLabel, '15.0 km');
    expect(order.etaLabel, '1 hr 10 min');
  });

  test('a failed order fetch keeps the offer trip data', () {
    final RiderOffer active = _offer(
      'offer-a',
      tripFare: 500,
      distanceKm: 12.4,
      estimatedDurationSeconds: 2100,
    );
    final RiderOrder order = OrderMapper.toRiderOrder(
      offer: acceptedOfferState(active: active),
    );
    expect(order.tripAmount, 500);
    expect(order.distanceLabel, '12.4 km');
    expect(order.etaLabel, '35 min');
  });
}

RiderOffer _offer(
  String offerId, {
  double? tripFare,
  double? distanceKm,
  int? estimatedDurationSeconds,
}) {
  return RiderOffer(
    offerId: offerId,
    orderId: '55555555-5555-4555-8555-555555555555',
    status: 'PENDING',
    createdAt: DateTime.utc(2026, 10, 9),
    displayId: 'IU-1',
    tripFare: tripFare,
    distanceKm: distanceKm,
    estimatedDurationSeconds: estimatedDurationSeconds,
    pickupAddress: 'Pickup lane',
    dropAddress: 'Drop lane',
  );
}
