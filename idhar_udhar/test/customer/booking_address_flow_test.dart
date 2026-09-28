import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

void main() {
  late ProviderContainer container;
  late BookingDraftNotifier notifier;

  MockLocation loc(String id) =>
      MockData.locations.firstWhere((MockLocation item) => item.id == id);

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(bookingDraftProvider.notifier);
  });

  tearDown(() => container.dispose());

  BookingDraft draft() => container.read(bookingDraftProvider);

  MockLocation confirmedCopy(MockLocation location) {
    return location.copyWith(unit: 'A-204', premises: 'Sunrise Heights');
  }

  test('startup device location becomes pickup and is not address-confirmed', () {
    const MockLocation gps = MockLocation(
      id: 'gps_pickup',
      label: 'Current location',
      address: 'Colaba, Mumbai',
      city: 'Mumbai',
      iconName: 'my_location',
      latitude: 19.076,
      longitude: 72.877,
    );
    notifier.applyDevicePickup(gps);

    expect(draft().pickup?.id, 'gps_pickup');
    expect(draft().pickup?.latitude, 19.076);
    expect(draft().pickup?.longitude, 72.877);
    expect(draft().pickupAddressConfirmed, isFalse);
    expect(draft().needsPickupConfirmationFor(gps), isTrue);
    expect(draft().readyForRoutePreview, isFalse);
  });

  test('pickup selection stays unconfirmed until the address is confirmed', () {
    final MockLocation selected = loc('loc_paldi');
    notifier.setPickup(selected);

    expect(draft().pickup?.id, 'loc_paldi');
    expect(draft().pickupAddressConfirmed, isFalse);
    expect(draft().needsPickupConfirmationFor(selected), isTrue);
  });

  test('confirmed pickup is not asked again unless the pin changes', () {
    final MockLocation selected = loc('loc_paldi');
    final MockLocation confirmed = confirmedCopy(selected);
    notifier.setPickup(selected);
    notifier.confirmPickupAddress(confirmed);

    expect(draft().pickupAddressConfirmed, isTrue);
    expect(draft().needsPickupConfirmationFor(selected), isFalse);
    expect(draft().needsPickupConfirmationFor(confirmed), isFalse);
    expect(draft().pickup?.latitude, selected.latitude);
    expect(draft().pickup?.longitude, selected.longitude);
    expect(draft().pickup?.id, 'loc_paldi');
    expect(
      draft().pickupAddressText,
      'A-204, Sunrise Heights, Paldi Cross Road, Ahmedabad',
    );

    notifier.setPickup(loc('loc_bopal'));
    expect(draft().pickupAddressConfirmed, isFalse);
    expect(draft().needsPickupConfirmationFor(loc('loc_bopal')), isTrue);
  });

  test('drop selection stays unconfirmed until the address is confirmed', () {
    final MockLocation selected = loc('loc_bopal');
    notifier.setDrop(selected);

    expect(draft().drop?.id, 'loc_bopal');
    expect(draft().dropConfirmedAt(0), isFalse);
    expect(draft().needsDropConfirmationFor(selected, 0), isTrue);
    expect(draft().readyForRoutePreview, isFalse);
  });

  test('confirmed drop is not asked again unless the pin changes', () {
    final MockLocation selected = loc('loc_bopal');
    final MockLocation confirmed = confirmedCopy(selected);
    notifier.confirmPickupAddress(confirmedCopy(loc('loc_paldi')));
    notifier.setDrop(selected);
    notifier.confirmDropAddress(confirmed);

    expect(draft().dropConfirmedAt(0), isTrue);
    expect(draft().needsDropConfirmationFor(selected, 0), isFalse);
    expect(draft().readyForRoutePreview, isTrue);
    expect(draft().drop?.latitude, selected.latitude);
    expect(draft().drop?.longitude, selected.longitude);
    expect(draft().drop?.id, 'loc_bopal');
    expect(
      draft().locationAddress(draft().drop!),
      'A-204, Sunrise Heights, Bopal, Ahmedabad',
    );

    notifier.setDrop(loc('loc_office'));
    expect(draft().dropConfirmedAt(0), isFalse);
    expect(draft().readyForRoutePreview, isFalse);
    expect(draft().needsDropConfirmationFor(loc('loc_office'), 0), isTrue);
  });

  test('address confirmation does not move pickup or drop coordinates', () {
    final MockLocation pickup = loc('loc_paldi');
    final MockLocation drop = loc('loc_bopal');
    notifier.confirmPickupAddress(confirmedCopy(pickup));
    notifier.confirmDropAddress(confirmedCopy(drop));

    expect(draft().pickup?.latitude, pickup.latitude);
    expect(draft().pickup?.longitude, pickup.longitude);
    expect(draft().drop?.latitude, drop.latitude);
    expect(draft().drop?.longitude, drop.longitude);
  });

  test('multi-drop confirmation is per stop and a changed stop is invalidated', () {
    notifier.setDeliveryMode(DeliveryMode.multiple);
    notifier.setDropCount(2);
    notifier.confirmPickupAddress(confirmedCopy(loc('loc_sg')));
    notifier.confirmDropAddress(confirmedCopy(loc('loc_paldi')));
    notifier.confirmDropAddress(confirmedCopy(loc('loc_bopal')), index: 1);

    expect(draft().dropConfirmedAt(0), isTrue);
    expect(draft().dropConfirmedAt(1), isTrue);
    expect(draft().readyForRoutePreview, isTrue);
    expect(draft().allDrops.map((MockLocation item) => item.id), [
      'loc_paldi',
      'loc_bopal',
    ]);

    notifier.setDropAt(1, loc('loc_office'));
    expect(draft().dropAt(1)?.id, 'loc_office');
    expect(draft().dropConfirmedAt(0), isTrue);
    expect(draft().dropConfirmedAt(1), isFalse);
    expect(draft().readyForRoutePreview, isFalse);
  });

  test('route distance is stored only from a routes result', () {
    const DisplayRoute route = DisplayRoute(
      points: <GeoPoint>[
        GeoPoint(latitude: 23.0115, longitude: 72.5650),
        GeoPoint(latitude: 21.1418, longitude: 72.7709),
      ],
      distanceMeters: 12400,
      durationSeconds: 1500,
    );
    final double straightKm = GeoMath.haversineKm(
      lat1: 23.0115,
      lng1: 72.5650,
      lat2: 21.1418,
      lng2: 72.7709,
    );

    expect(draft().routeDistanceMeters, isNull);
    expect(route.distanceLabel, '12.4 km');
    expect(route.distanceLabel, isNot('${straightKm.toStringAsFixed(1)} km'));

    notifier.recordRoute(
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
    );
    expect(draft().routeDistanceMeters, route.distanceMeters);
    expect(draft().routeDurationSeconds, route.durationSeconds);

    notifier.recordRoute();
    expect(draft().routeDistanceMeters, isNull);
    expect(draft().routeDurationSeconds, isNull);

    expect(
      const DisplayRoute(
        points: <GeoPoint>[
          GeoPoint(latitude: 23.0, longitude: 72.0),
          GeoPoint(latitude: 23.001, longitude: 72.001),
        ],
        distanceMeters: 850,
        durationSeconds: 120,
      ).distanceLabel,
      '850 m',
    );
  });
}
