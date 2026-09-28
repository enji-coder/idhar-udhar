import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/constants/asset_paths.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';

void main() {
  late ProviderContainer container;
  late BookingDraftNotifier notifier;

  MockLocation loc(String id) =>
      MockData.locations.firstWhere((l) => l.id == id);

  MockOrder searchingOrder(String id, MockLocation drop) {
    return MockOrder(
      id: id,
      status: OrderStatus.searching,
      pickup: MockData.locations[4],
      drop: drop,
      vehicle: MockData.vehicles.first,
      fare: 0,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(bookingDraftProvider.notifier);
  });

  tearDown(() => container.dispose());

  BookingDraft draft() => container.read(bookingDraftProvider);

  test('each drop index is stored independently', () {
    notifier.setDeliveryMode(DeliveryMode.multiple);
    notifier.setDropCount(3);
    notifier.setDropAt(0, loc('loc_paldi'));
    notifier.setDropAt(1, loc('loc_bopal'));
    notifier.setDropAt(2, loc('loc_office'));

    expect(draft().dropAt(0)?.id, 'loc_paldi');
    expect(draft().dropAt(1)?.id, 'loc_bopal');
    expect(draft().dropAt(2)?.id, 'loc_office');
    expect(draft().allDrops.map((d) => d.id), [
      'loc_paldi',
      'loc_bopal',
      'loc_office',
    ]);
  });

  test('switching 3 drops to 2 does not submit drop 3', () {
    notifier.setDeliveryMode(DeliveryMode.multiple);
    notifier.setDropCount(3);
    notifier.setDropAt(0, loc('loc_paldi'));
    notifier.setDropAt(1, loc('loc_bopal'));
    notifier.setDropAt(2, loc('loc_office'));
    notifier.setDropCount(2);

    expect(draft().dropCount, 2);
    expect(draft().dropAt(2), isNull);
    expect(draft().allDrops.map((d) => d.id), ['loc_paldi', 'loc_bopal']);
  });

  test('confirm is blocked until every required drop is selected', () {
    notifier.setDeliveryMode(DeliveryMode.multiple);
    notifier.setDropCount(2);
    notifier.setDropAt(0, loc('loc_paldi'));

    expect(draft().incompleteStopMessage, 'Select Drop Location 2');

    notifier.setDropCount(3);
    notifier.setDropAt(1, loc('loc_bopal'));
    expect(draft().incompleteStopMessage, 'Select Drop Location 3');

    notifier.setDropAt(2, loc('loc_office'));
    expect(draft().incompleteStopMessage, isNull);
  });

  test('a new booking does not keep the previous drop', () {
    notifier.setDrop(loc('loc_paldi'));
    notifier.beginNewBooking();
    notifier.setDrop(loc('loc_bopal'));

    expect(draft().drop?.id, 'loc_bopal');
    expect(draft().allDrops.map((d) => d.id), ['loc_bopal']);
  });

  test('advancing order A does not rewrite order B in the draft', () {
    final MockOrder a = searchingOrder('IU-A', loc('loc_paldi'));
    notifier.attachActive(a);
    notifier.assignRider();
    final MockOrder assignedA = draft().activeOrder!;
    expect(assignedA.id, a.id);
    expect(assignedA.status, OrderStatus.assigned);

    notifier.beginNewBooking();
    final MockOrder b = searchingOrder('IU-B', loc('loc_bopal'));
    notifier.attachActive(b);
    expect(draft().activeOrder?.id, b.id);
    expect(draft().activeOrder?.status, OrderStatus.searching);

    final MockOrder? updatedA = notifier.advanceDemoStatus(order: assignedA);
    expect(updatedA!.id, a.id);
    expect(updatedA.status, OrderStatus.accepted);
    expect(draft().activeOrder?.id, b.id);
    expect(draft().activeOrder?.status, OrderStatus.searching);
  });

  test('selected vehicle artwork follows bike, scooty, and truck', () {
    notifier.setVehicle(
      MockData.vehicles.firstWhere((MockVehicle v) => v.type == VehicleType.bike),
    );
    expect(draft().vehicle!.imagePath, AssetPaths.bike);

    notifier.setVehicle(
      MockData.vehicles.firstWhere((MockVehicle v) => v.type == VehicleType.scooty),
    );
    expect(draft().vehicle!.imagePath, AssetPaths.scooty);
    expect(draft().vehicle!.imagePath, isNot(AssetPaths.truck));

    notifier.setVehicle(
      MockData.vehicles.firstWhere((MockVehicle v) => v.type == VehicleType.truck),
    );
    expect(draft().vehicle!.imagePath, AssetPaths.truck);
  });

  test('two wheeler address keeps house and society editable and separate', () {
    notifier.setServiceFamily(ServiceFamily.twoWheeler);
    notifier.setPickup(loc('loc_paldi'));
    notifier.setPickupUnit(house: 'B-12', society: 'Sunrise Society');

    expect(draft().usesResidentialPickup, isTrue);
    expect(draft().pickup!.address, 'Paldi Cross Road, Ahmedabad');
    expect(
      draft().pickupAddressText,
      'B-12, Sunrise Society, Paldi Cross Road, Ahmedabad',
    );
  });

  test('truck address text includes the entered house and building', () {
    notifier.setServiceFamily(ServiceFamily.truck);
    notifier.setPickup(loc('loc_paldi'));
    notifier.setPickupUnit(house: 'B-12', society: 'Sunrise Society');

    expect(draft().usesResidentialPickup, isFalse);
    expect(
      draft().pickupAddressText,
      'B-12, Sunrise Society, Paldi Cross Road, Ahmedabad',
    );
  });

  test('display address joins unit, premises, and full location', () {
    expect(
      MockLocation.composeAddress(
        unit: 'A-204',
        premises: 'Sunrise Heights',
        address: '100 Feet Road, Satellite, Ahmedabad, Gujarat',
      ),
      'A-204, Sunrise Heights, 100 Feet Road, Satellite, Ahmedabad, Gujarat',
    );
    expect(
      MockLocation.composeAddress(
        unit: '',
        premises: 'Sunrise Heights',
        address: '100 Feet Road, Satellite, Ahmedabad',
      ),
      'Sunrise Heights, 100 Feet Road, Satellite, Ahmedabad',
    );
    expect(
      MockLocation.composeAddress(
        unit: 'A-204',
        premises: '',
        address: '100 Feet Road, Satellite, Ahmedabad',
      ),
      'A-204, 100 Feet Road, Satellite, Ahmedabad',
    );
    expect(
      MockLocation.composeAddress(
        unit: '',
        premises: '',
        address: '100 Feet Road, Satellite, Ahmedabad, Gujarat',
      ),
      '100 Feet Road, Satellite, Ahmedabad, Gujarat',
    );
    expect(
      MockLocation.composeAddress(
        unit: 'A-204',
        premises: 'Sunrise Heights',
        address: 'A-204, Sunrise Heights, 100 Feet Road, Satellite, Ahmedabad',
      ),
      'A-204, Sunrise Heights, 100 Feet Road, Satellite, Ahmedabad',
    );
  });

  test('confirmed pickup and drop keep coordinates and show the combined address', () {
    const MockLocation pickup = MockLocation(
      id: 'pickup_1',
      label: 'Satellite',
      address: '100 Feet Road, Satellite, Ahmedabad, Gujarat',
      unit: 'A-204',
      premises: 'Sunrise Heights',
      latitude: 23.03,
      longitude: 72.51,
    );
    const MockLocation drop = MockLocation(
      id: 'drop_1',
      label: 'Bopal',
      address: '100 Feet Road, Satellite, Ahmedabad',
      unit: 'A-204',
      premises: 'Sunrise Heights',
      latitude: 23.04,
      longitude: 72.48,
    );
    notifier.setPickup(pickup);
    notifier.setPickupUnit(house: pickup.unit, society: pickup.premises);
    notifier.setDrop(drop);

    expect(draft().pickup!.latitude, 23.03);
    expect(draft().pickup!.longitude, 72.51);
    expect(draft().pickup!.address, pickup.address);
    expect(draft().pickup!.unit, 'A-204');
    expect(draft().pickup!.premises, 'Sunrise Heights');
    expect(
      draft().pickupAddressText,
      'A-204, Sunrise Heights, 100 Feet Road, Satellite, Ahmedabad, Gujarat',
    );
    expect(draft().drop!.latitude, 23.04);
    expect(draft().drop!.longitude, 72.48);
    expect(
      draft().locationAddress(draft().drop!),
      'A-204, Sunrise Heights, 100 Feet Road, Satellite, Ahmedabad',
    );
  });
}
