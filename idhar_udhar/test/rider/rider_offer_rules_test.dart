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
