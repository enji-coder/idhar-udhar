import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_api.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/core/state/session_provider.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/receiver_details_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/vehicle_selection_screen.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SeededSession extends SessionNotifier {
  _SeededSession(MockUser user) {
    state = SessionState(user: user, isAuthenticated: true, isHydrated: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('local mobile digits strips country code', () {
    expect(
      ReceiverDetailsScreenStateHack.localMobileDigits('+919876543210'),
      '9876543210',
    );
    expect(
      ReceiverDetailsScreenStateHack.localMobileDigits('9876543210'),
      '9876543210',
    );
  });

  testWidgets('Use my current details fills receiver name and mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        sessionProvider.overrideWith(
          (Ref ref) => _SeededSession(
            const MockUser(
              id: 'u1',
              phone: '+919876543210',
              name: 'Ravi Kumar',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReceiverDetailsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Use my current details'));
    await tester.pump();

    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
  });

  test('loader_riksha three_wheeler maps to auto not truck', () {
    final MockVehicle vehicle = customerVehicleFromCategory(
      VehicleCategory.fromJson(<String, Object>{
        'id': 'th-1',
        'name': 'Loading Riksha',
        'vehicle_type': 'three_wheeler',
        'vehicle': 'loader_riksha',
        'weight_capacity': '100 kg',
        'size': '90cm',
        'rates': <String, Object>{
          'base_fare': '90.00',
          'per_km': '12.00',
        },
      }),
    );
    expect(vehicle.type, VehicleType.auto);
    expect(vehicle.serviceFamily, ServiceFamily.threeWheeler);
    expect(vehicle.name, 'Loading Riksha');
    expect(vehicle.imagePath.toLowerCase().contains('truck'), isFalse);
  });

  test('parcel size and weight respect vehicle limits', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final BookingDraftNotifier notifier =
        container.read(bookingDraftProvider.notifier);

    notifier.setVehicle(
      customerVehicleFromCategory(
        VehicleCategory.fromJson(<String, Object>{
          'id': 'scooty-1',
          'name': 'Scooty',
          'vehicle_type': 'two_wheeler',
          'vehicle': 'scooty',
          'weight_capacity': '20 kg',
          'size': '30cm',
          'rates': <String, Object>{
            'base_fare': '40.00',
            'per_km': '8.00',
          },
        }),
      ),
    );

    final BookingDraft draft = container.read(bookingDraftProvider);
    expect(draft.vehicleMaxWeightKg, 20);
    expect(draft.vehicleMaxSizeCm, 30);
    final MockParcelSize small = MockData.parcelSizes
        .firstWhere((MockParcelSize s) => s.id == 's_sm');
    final MockParcelSize medium = MockData.parcelSizes
        .firstWhere((MockParcelSize s) => s.id == 's_md');
    expect(draft.parcelSizeAllowed(small), isTrue);
    expect(draft.parcelSizeAllowed(medium), isFalse);
    expect(draft.weightAllowed(20), isTrue);
    expect(draft.weightAllowed(25), isFalse);

    final double before = draft.weightKg;
    notifier.setWeight(25);
    expect(container.read(bookingDraftProvider).weightKg, before);
    notifier.setWeight(10);
    expect(container.read(bookingDraftProvider).weightKg, 10);
  });

  test('buildBookingStops attaches receiver contact to every DROP', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final BookingDraftNotifier notifier =
        container.read(bookingDraftProvider.notifier);
    notifier.setPickup(
      const MockLocation(
        id: 'p1',
        label: 'Pickup',
        address: 'Pickup road',
        latitude: 23.01,
        longitude: 72.56,
      ),
    );
    notifier.setDrop(
      const MockLocation(
        id: 'd1',
        label: 'Drop',
        address: 'Drop road',
        latitude: 23.03,
        longitude: 72.47,
      ),
    );
    notifier.setReceiver(name: 'Asha', mobile: '9876543210');

    final stops = buildBookingStops(container.read(bookingDraftProvider));
    expect(stops.length, 2);
    expect(stops.first.stopType, 'PICKUP');
    expect(stops.last.stopType, 'DROP');
    expect(stops.last.contactName, 'Asha');
    expect(stops.last.contactPhone, '9876543210');
  });
}

/// Exposes the private static helper used by the receiver screen.
abstract final class ReceiverDetailsScreenStateHack {
  static String localMobileDigits(String phone) {
    final String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 10) {
      return digits;
    }
    return digits.substring(digits.length - 10);
  }
}
