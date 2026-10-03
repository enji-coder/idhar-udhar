import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_api.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/package_details_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/pickup_to_drop_preview_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/vehicle_selection_screen.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';

/// Prevents Package Details quote prefetch from opening a real HTTP client.
class _SkipQuoteOrdersApi extends OrdersApi {
  _SkipQuoteOrdersApi() : super(ApiClient(tokenStore: TokenStore()));

  @override
  Future<ApiOrder> create({
    required String cityId,
    required String vehicleCategoryId,
    required List<ApiStop> stops,
    double? packageWeightKg,
    double? packageSizeCm,
    String? idempotencyKey,
  }) async {
    throw const ApiException(
        code: 'TEST_SKIP', message: 'quote skipped in test');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late BookingDraftNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(bookingDraftProvider.notifier);
  });

  tearDown(() => container.dispose());

  BookingDraft draft() => container.read(bookingDraftProvider);

  MockVehicle vehicle({
    required String id,
    required VehicleType type,
    required String name,
    required double base,
    required double perKm,
    String capacity = '20 KG',
    double? initialMinimum,
    double surge = 0,
    double toll = 0,
    double parking = 0,
  }) {
    return MockVehicle(
      id: id,
      type: type,
      name: name,
      description: 'Admin category',
      capacity: capacity,
      etaMinutes: 0,
      baseFare: base,
      perKm: perKm,
      initialMinimum: initialMinimum,
      surge: surge,
      toll: toll,
      parking: parking,
      imagePath: 'assets/vehicle.png',
    );
  }

  void seedRoute(double km) {
    notifier.setPickup(
      MockData.locations
          .firstWhere((MockLocation loc) => loc.id == 'loc_paldi'),
    );
    notifier.setDrop(
      MockData.locations
          .firstWhere((MockLocation loc) => loc.id == 'loc_bopal'),
    );
    notifier.applyRouteResult(
      signature: draft().currentRouteKey,
      distanceKm: km,
      durationSeconds: 1200,
    );
  }

  test('bike fare is base plus distance times the admin per-km rate', () {
    seedRoute(10);
    notifier.setVehicle(
      vehicle(
        id: 'bike-1',
        type: VehicleType.bike,
        name: 'Bike',
        base: 40,
        perKm: 8,
      ),
    );

    final FareQuote quote = draft().fareQuote;
    expect(quote.distanceKm, 10);
    expect(quote.baseFare, 40);
    expect(quote.perKmCharge, 8);
    expect(quote.distanceCharge, 80);
    expect(quote.netTotal, 120);
    expect(draft().estimatedFare, 120);
    expect(draft().payableTotal, 0);
    expect(
      GeoMath.routeKm(draft().orderedStops),
      isNot(closeTo(10, 0.05)),
    );
  });

  test('scooty uses its own admin rate for the same distance', () {
    seedRoute(10);
    notifier.setVehicle(
      vehicle(
        id: 'scooty-1',
        type: VehicleType.scooty,
        name: 'Scooty',
        base: 30,
        perKm: 12,
        capacity: '15 KG',
      ),
    );

    expect(draft().fareQuote.perKmCharge, 12);
    expect(draft().fareQuote.distanceCharge, 120);
    expect(draft().estimatedFare, 150);
    expect(draft().vehicle?.capacity, '15 KG');
  });

  test(
      'the same rates produce a different fare when the route distance changes',
      () {
    final MockVehicle bike = vehicle(
      id: 'bike-1',
      type: VehicleType.bike,
      name: 'Bike',
      base: 40,
      perKm: 8,
    );
    seedRoute(10);
    notifier.setVehicle(bike);
    expect(draft().estimatedFare, 120);

    notifier.applyRouteResult(
      signature: draft().currentRouteKey,
      distanceKm: 4,
      durationSeconds: 600,
    );
    expect(draft().fareQuote.distanceKm, 4);
    expect(draft().fareQuote.distanceCharge, 32);
    expect(draft().estimatedFare, 72);
  });

  test('a changed admin rate is used with no hardcoded fare fallback', () {
    seedRoute(10);
    notifier.setVehicle(
      vehicle(
        id: 'bike-1',
        type: VehicleType.bike,
        name: 'Bike',
        base: 40,
        perKm: 8,
      ),
    );
    expect(draft().estimatedFare, 120);

    notifier.setVehicle(
      vehicle(
        id: 'bike-1',
        type: VehicleType.bike,
        name: 'Bike',
        base: 55,
        perKm: 11,
        surge: 5,
      ),
    );
    expect(draft().fareQuote.baseFare, 55);
    expect(draft().fareQuote.perKmCharge, 11);
    expect(draft().fareQuote.distanceCharge, 110);
    expect(draft().fareQuote.surgeCharge, 5);
    expect(draft().estimatedFare, 170);
    expect(draft().estimatedFare, isNot(120));
  });

  test('admin weight capacity is unchanged and is not used as distance', () {
    const String capacity = '20 KG';
    final VehicleCategory category = VehicleCategory.fromJson(<String, Object>{
      'vehicle_category_id': 'bike-1',
      'name': 'Bike',
      'active': true,
      'weight_capacity': capacity,
      'vehicle_type': 'two_wheeler',
      'vehicle': 'bike',
      'rates': <String, Object>{
        'base_fare': '40.00',
        'per_km': '8.00',
        'initial_minimum': '10.00',
      },
    });
    final MockVehicle bike = customerVehicleFromCategory(category);
    expect(bike.capacity, capacity);
    expect(bike.baseFare, 40);
    expect(bike.perKm, 8);
    expect(category.weightCapacity, capacity);

    seedRoute(10);
    notifier.setVehicle(bike);
    expect(draft().vehicle?.capacity, capacity);
    expect(draft().fareQuote.distanceKm, 10);
    expect(draft().estimatedFare, 120);

    notifier.applyQuotedPayable(40);
    expect(draft().payableTotal, 40);
    expect(draft().estimatedFare, 120);
  });

  testWidgets('vehicle choices and parcel details show the calculated fare', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() {
      VehicleCategoryCatalog.launchCityId = null;
    });

    final VehicleCategory bike = VehicleCategory.fromJson(<String, Object>{
      'vehicle_category_id': 'bike-1',
      'name': 'Bike',
      'active': true,
      'weight_capacity': '20 KG',
      'vehicle_type': 'two_wheeler',
      'vehicle': 'bike',
      'rates': <String, Object>{
        'base_fare': '40.00',
        'per_km': '8.00',
      },
    });
    final VehicleCategory scooty = VehicleCategory.fromJson(<String, Object>{
      'vehicle_category_id': 'scooty-1',
      'name': 'Scooty',
      'active': true,
      'weight_capacity': '15 KG',
      'vehicle_type': 'two_wheeler',
      'vehicle': 'scooty',
      'rates': <String, Object>{
        'base_fare': '30.00',
        'per_km': '12.00',
      },
    });
    VehicleCategoryCatalog.launchCityId =
        '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc';
    final ProviderContainer priced = ProviderContainer(
      overrides: <Override>[
        vehicleCategoryCatalogProvider.overrideWith(
          (Ref ref) async => <VehicleCategory>[bike, scooty],
        ),
        vehicleFarePreviewProvider.overrideWith(
          (Ref ref) async => <String, String>{
            'bike-1': '160.00',
            'scooty-1': '140.00',
          },
        ),
        ordersApiProvider.overrideWithValue(_SkipQuoteOrdersApi()),
      ],
    );
    addTearDown(priced.dispose);
    final BookingDraftNotifier pricedDraft =
        priced.read(bookingDraftProvider.notifier);
    pricedDraft.setPickup(
      MockData.locations
          .firstWhere((MockLocation loc) => loc.id == 'loc_paldi'),
    );
    pricedDraft.setDrop(
      MockData.locations
          .firstWhere((MockLocation loc) => loc.id == 'loc_bopal'),
    );
    pricedDraft.applyRouteResult(
      signature: priced.read(bookingDraftProvider).currentRouteKey,
      distanceKm: 10,
      durationSeconds: 1200,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: priced,
        child: const MaterialApp(home: VehicleSelectionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('₹160.00'), findsOneWidget);
    expect(find.text('₹140.00'), findsOneWidget);
    expect(find.text('Base ₹40'), findsNothing);
    expect(find.text('Base ₹30'), findsNothing);
    expect(find.text('20 KG'), findsOneWidget);
    expect(find.text('15 KG'), findsOneWidget);

    pricedDraft.setVehicle(customerVehicleFromCategory(bike));
    pricedDraft.setReceiver(name: 'Test Receiver', mobile: '9876543210');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: priced,
        child: const MaterialApp(home: PackageDetailsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estimated Fare'), findsOneWidget);
    expect(find.text('₹160'), findsOneWidget);
    expect(find.text('Calculating...'), findsNothing);
    expect(find.text('Unable to calculate fare'), findsNothing);
    expect(find.text('Fare calculated at summary'), findsNothing);
  });

  test('scooty and bike each use their own admin base and per-km rate', () {
    seedRoute(10);
    notifier.setVehicle(
      vehicle(
        id: 'scooty-1',
        type: VehicleType.scooty,
        name: 'Scooty',
        base: 50,
        perKm: 8,
      ),
    );
    expect(draft().customerVisibleFare, isNull);
    expect(draft().fareQuote.distanceCharge, 80);

    notifier.setVehicle(
      vehicle(
        id: 'bike-1',
        type: VehicleType.bike,
        name: 'Bike',
        base: 60,
        perKm: 10,
      ),
    );
    expect(draft().fareQuote.baseFare, 60);
    expect(draft().fareQuote.perKmCharge, 10);
    expect(draft().fareQuote.distanceKm, 10);
    expect(draft().fareQuote.distanceCharge, 100);
    expect(draft().customerVisibleFare, isNull);
    expect(draft().payableTotal, 0);
  });

  test('without a successful route there is no distance-based fare', () {
    notifier.setPickup(
      MockData.locations
          .firstWhere((MockLocation loc) => loc.id == 'loc_paldi'),
    );
    notifier.setDrop(
      MockData.locations
          .firstWhere((MockLocation loc) => loc.id == 'loc_bopal'),
    );
    notifier.setVehicle(
      vehicle(
        id: 'scooty-1',
        type: VehicleType.scooty,
        name: 'Scooty',
        base: 50,
        perKm: 8,
      ),
    );

    expect(draft().hasRouteForCurrentStops, isFalse);
    expect(draft().canEstimateFare, isFalse);
    expect(draft().customerVisibleFare, isNull);
    expect(draft().billableDistanceKm, isNull);
    expect(draft().fareQuote.distanceKm, 0);
    expect(draft().fareQuote.distanceCharge, 0);
    expect(
      draft().fareQuote.distanceKm,
      isNot(GeoMath.routeKm(draft().orderedStops)),
    );
  });

  test('a new drop clears the previous calculated fare', () {
    seedRoute(10);
    notifier.setVehicle(
      vehicle(
        id: 'scooty-1',
        type: VehicleType.scooty,
        name: 'Scooty',
        base: 50,
        perKm: 8,
      ),
    );
    expect(draft().customerVisibleFare, isNull);

    notifier.setDrop(
      const MockLocation(
        id: 'drop_other',
        label: 'Other',
        address: 'Other drop',
        latitude: 23.08,
        longitude: 72.58,
      ),
    );

    expect(draft().hasRouteForCurrentStops, isFalse);
    expect(draft().customerVisibleFare, isNull);
    expect(draft().payableTotal, 0);
    expect(draft().fareQuote.distanceCharge, 0);
  });

  testWidgets('route result makes the calculated fare visible on the preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    seedRoute(10);
    notifier.setVehicle(
      vehicle(
        id: 'scooty-1',
        type: VehicleType.scooty,
        name: 'Scooty',
        base: 50,
        perKm: 8,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PickupToDropPreviewScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Estimated Fare'), findsNothing);
    expect(find.text('₹130'), findsNothing);
    expect(find.textContaining('Base ₹'), findsNothing);
  });
}
