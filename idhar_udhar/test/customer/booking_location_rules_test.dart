import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/routing/app_routes.dart';
import 'package:idhar_udhar/customer/core/state/booking_api.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/core/state/saved_addresses_provider.dart';
import 'package:idhar_udhar/customer/core/widgets/animated_primary_button.dart';
import 'package:idhar_udhar/customer/core/widgets/glass_text_field.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/booking_summary_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/complete_address_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/drop_location_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/pickup_to_drop_preview_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/receiver_details_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/vehicle_selection_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/widgets/booking_route_preview.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:idhar_udhar/shared/maps/geo_point.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MockLocation gps = MockLocation(
    id: 'device_gps',
    label: 'Current location',
    address: 'Colaba, Mumbai',
    latitude: 19.076,
    longitude: 72.8777,
  );
  const MockLocation place = MockLocation(
    id: 'place_b',
    label: 'Satellite',
    address: 'Satellite, Ahmedabad, Gujarat',
    latitude: 23.0225,
    longitude: 72.5714,
  );

  late ProviderContainer container;
  late BookingDraftNotifier notifier;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    container = ProviderContainer();
    notifier = container.read(bookingDraftProvider.notifier);
  });

  tearDown(() => container.dispose());

  BookingDraft draft() => container.read(bookingDraftProvider);

  MockVehicle scooty({double base = 40, double perKm = 8}) {
    return MockVehicle(
      id: 'scooty-1',
      type: VehicleType.scooty,
      name: 'Scooty',
      description: 'City drops',
      capacity: '20 kg',
      etaMinutes: 0,
      baseFare: base,
      perKm: perKm,
      imagePath: 'assets/scooty.png',
    );
  }

  void seedRoute({double km = 10}) {
    notifier.setPickup(MockData.locations.firstWhere((l) => l.id == 'loc_paldi'));
    notifier.setDrop(MockData.locations.firstWhere((l) => l.id == 'loc_bopal'));
    notifier.applyRouteResult(
      signature: draft().currentRouteKey,
      distanceKm: km,
      durationSeconds: 1440,
    );
  }

  test('GPS stays unchanged when another pickup is selected', () {
    notifier.setDeviceLocation(gps);
    notifier.setPickup(place);

    expect(draft().deviceLocation?.id, 'device_gps');
    expect(draft().deviceLocation?.latitude, 19.076);
    expect(draft().deviceLocation?.longitude, 72.8777);
    expect(draft().pickup?.id, 'place_b');
    expect(draft().pickup?.latitude, 23.0225);
  });

  test('Current Location copies GPS into pickup and leaves GPS in place', () {
    notifier.setDeviceLocation(gps);
    notifier.useDeviceLocationAsPickup();
    notifier.setPickup(place);

    expect(draft().deviceLocation?.latitude, gps.latitude);
    expect(draft().deviceLocation?.longitude, gps.longitude);
    expect(draft().deviceLocation?.address, gps.address);
    expect(draft().pickup?.id, 'place_b');

    notifier.useDeviceLocationAsPickup();
    expect(draft().pickup?.id, 'pickup_current');
    expect(draft().pickup?.latitude, gps.latitude);
    expect(draft().pickup?.longitude, gps.longitude);
    expect(draft().deviceLocation?.id, 'device_gps');
    expect(draft().deviceLocation?.latitude, gps.latitude);
  });

  test('pickup address details do not populate drop address details', () {
    final MockLocation pickup = place.copyWith(
      unit: '101',
      premises: 'Shreyansh Tower',
      landmark: 'Satellite Road',
    );
    notifier.setPickup(pickup);
    notifier.setPickupUnit(house: '101', society: 'Shreyansh Tower');
    notifier.setDrop(
      const MockLocation(
        id: 'drop_same_label',
        label: 'Bopal',
        address: 'Bopal, Ahmedabad',
        latitude: 23.03,
        longitude: 72.47,
      ),
    );

    expect(draft().drop?.unit, isEmpty);
    expect(draft().drop?.premises, isEmpty);
    expect(draft().drop?.landmark, isEmpty);
    expect(
      draft().locationAddress(draft().drop!),
      'Bopal, Ahmedabad',
    );
    expect(
      draft().locationAddress(draft().pickup!),
      '101, Shreyansh Tower, Satellite, Ahmedabad, Gujarat',
    );
  });

  testWidgets('drop location does not render recent searches', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DropLocationScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Recent searches'), findsNothing);
    expect(find.text('Recent Search'), findsNothing);
    expect(find.text('No recent searches'), findsNothing);
    expect(find.text('Saved addresses'), findsOneWidget);
    expect(find.text('Select on Map'), findsOneWidget);
    expect(find.text('Saved Address'), findsOneWidget);
  });

  testWidgets('drop address form does not inherit pickup house or building', (
    tester,
  ) async {
    notifier.setPickup(place.copyWith(unit: '101', premises: 'Shreyansh Tower'));
    notifier.setPickupUnit(house: '101', society: 'Shreyansh Tower');
    const MockLocation dropPin = MockLocation(
      id: 'drop_pin',
      label: 'Bopal',
      address: 'Bopal, Ahmedabad',
      latitude: 23.03,
      longitude: 72.47,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CompleteAddressScreen(initial: dropPin),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('101'), findsNothing);
    expect(find.text('Shreyansh Tower'), findsNothing);
    expect(find.text('Bopal, Ahmedabad'), findsOneWidget);
    expect(find.text('House No / Floor No / Block No / Office No'), findsOneWidget);
    expect(find.text('Building Name / Society Name / Office Name'), findsOneWidget);
    expect(find.text('Street Name / Near Location'), findsOneWidget);
    expect(find.text('Complete Address'), findsOneWidget);
  });

  testWidgets('empty house and building still confirm the Google address', (
    tester,
  ) async {
    MockLocation? confirmed;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () async {
                  confirmed = await CompleteAddressScreen.open(
                    context,
                    initial: place,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm Address'));
    await tester.tap(find.text('Confirm Address'));
    await tester.pumpAndSettle();

    expect(confirmed, isNotNull);
    expect(confirmed!.unit, isEmpty);
    expect(confirmed!.premises, isEmpty);
    expect(confirmed!.address, 'Satellite, Ahmedabad, Gujarat');
    expect(confirmed!.latitude, place.latitude);
    expect(confirmed!.longitude, place.longitude);
  });

  test('route distance feeds fare instead of straight-line distance', () {
    seedRoute(km: 3.5);
    notifier.setVehicle(scooty());
    final double straight = GeoMath.routeKm(draft().orderedStops);

    expect(draft().hasRouteForCurrentStops, isTrue);
    expect(draft().fareQuote.distanceKm, 3.5);
    expect(straight, isNot(closeTo(3.5, 0.05)));
    expect(draft().fareQuote.distanceCharge, 28);
    expect(draft().estimatedFare, 68);
  });

  test('scooty fare uses the vehicle base fare and per-km rate', () {
    seedRoute(km: 10);
    notifier.setVehicle(scooty(base: 40, perKm: 8));

    expect(draft().fareQuote.baseFare, 40);
    expect(draft().fareQuote.perKmCharge, 8);
    expect(draft().fareQuote.distanceCharge, 80);
    expect(draft().fareQuote.waitingCharge, 0);
    expect(draft().estimatedFare, 120);
  });

  test('fare recalculates when the vehicle or the route distance changes', () {
    seedRoute(km: 10);
    notifier.setVehicle(scooty(base: 40, perKm: 8));
    expect(draft().estimatedFare, 120);

    notifier.setVehicle(scooty(base: 79, perKm: 0));
    expect(draft().estimatedFare, 79);
    expect(draft().fareQuote.distanceKm, 10);

    notifier.setVehicle(scooty(base: 40, perKm: 8));
    notifier.applyRouteResult(
      signature: draft().currentRouteKey,
      distanceKm: 5,
      durationSeconds: 900,
    );
    expect(draft().fareQuote.distanceKm, 5);
    expect(draft().estimatedFare, 80);
  });

  test('receiver name and mobile are mandatory and separate from pickup', () {
    expect(BookingDraft.receiverNameError(''), 'Receiver name is required');
    expect(BookingDraft.receiverNameError('   '), 'Receiver name is required');
    expect(BookingDraft.receiverNameError('Asha'), isNull);
    expect(
      BookingDraft.receiverMobileError(''),
      'Mobile number is required',
    );
    expect(
      BookingDraft.receiverMobileError('12345'),
      'Enter a valid 10-digit mobile number',
    );
    expect(BookingDraft.receiverMobileError('9876543210'), isNull);

    notifier.setPickup(place.copyWith(unit: '101'));
    notifier.setReceiver(name: 'Asha', mobile: '9876543210');
    expect(draft().receiverName, 'Asha');
    expect(draft().receiverMobile, '9876543210');
    expect(draft().pickup?.unit, '101');
    expect(draft().pickup?.address, isNot('Asha'));
  });

  testWidgets('receiver screen blocks continue until name and mobile are valid', (
    tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, __) => const ReceiverDetailsScreen(),
        ),
        GoRoute(
          path: AppRoutes.bookPackage,
          builder: (_, __) => const Scaffold(body: Text('package-next')),
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(AnimatedPrimaryButton));
    await tester.pump();
    expect(find.text('Receiver name is required'), findsOneWidget);
    expect(find.text('Mobile number is required'), findsOneWidget);
    expect(draft().receiverName, isEmpty);

    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is GlassTextField && widget.label == "Receiver's name",
      ),
      'Asha',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is GlassTextField &&
            widget.label == "Receiver's mobile number",
      ),
      '98765',
    );
    await tester.tap(find.byType(AnimatedPrimaryButton));
    await tester.pump();
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
    expect(find.text('package-next'), findsNothing);

    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is GlassTextField &&
            widget.label == "Receiver's mobile number",
      ),
      '9876543210',
    );
    await tester.tap(find.byType(AnimatedPrimaryButton));
    await tester.pumpAndSettle();

    expect(draft().receiverName, 'Asha');
    expect(draft().receiverMobile, '9876543210');
    expect(find.text('package-next'), findsOneWidget);
  });

  testWidgets('preview keeps one route request for unchanged coordinates', (
    tester,
  ) async {
    const GeoPoint from = GeoPoint(latitude: 23.0115, longitude: 72.565);
    const GeoPoint to = GeoPoint(latitude: 23.03, longitude: 72.472);
    var calls = 0;
    Future<DisplayRoute?> load(List<GeoPoint> points) async {
      calls += 1;
      expect(points.first.latitude, from.latitude);
      expect(points.last.longitude, to.longitude);
      return const DisplayRoute(
        points: <GeoPoint>[from, to],
        distanceMeters: 10000,
        durationSeconds: 1440,
      );
    }

    final GlobalKey<_RebuildHostState> hostKey = GlobalKey<_RebuildHostState>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: _RebuildHost(key: hostKey, load: load),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Distance: 10.0 km'), findsOneWidget);
    expect(find.text('Approx. travel time: 24 min'), findsOneWidget);

    hostKey.currentState!.rebuild();
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('pickup to drop preview is the routed customer screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    notifier.setPickup(place);
    notifier.setDrop(
      const MockLocation(
        id: 'drop_pin',
        label: 'Bopal',
        address: 'Bopal, Ahmedabad',
        latitude: 23.03,
        longitude: 72.47,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PickupToDropPreviewScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Pickup To Drop Preview'), findsOneWidget);
    expect(find.text('Select on Map'), findsNothing);
    expect(find.text('Search on map'), findsNothing);
    expect(find.textContaining('Satellite, Ahmedabad, Gujarat'), findsOneWidget);
    expect(find.textContaining('Bopal, Ahmedabad'), findsOneWidget);
  });

  test('category rates price 2-wheeler, 3-wheeler, and truck', () {
    final List<MockVehicle> vehicles = <VehicleCategory>[
      VehicleCategory.fromJson(<String, Object>{
        'id': 'tw-1',
        'name': 'City Ride',
        'vehicle_type': 'two_wheeler',
        'vehicle': 'scooty',
        'rates': <String, Object>{
          'base_fare': '55.00',
          'per_km': '6.00',
          'waiting': '9.00',
        },
      }),
      VehicleCategory.fromJson(<String, Object>{
        'id': 'th-1',
        'name': 'City Loader',
        'vehicle_type': 'three_wheeler',
        'vehicle': 'loader_riksha',
        'rates': <String, Object>{
          'base_fare': '90.00',
          'per_km': '12.00',
          'surge': '15.00',
        },
      }),
      VehicleCategory.fromJson(<String, Object>{
        'id': 'tr-1',
        'name': 'Haul',
        'vehicle_type': 'truck',
        'vehicle': 'truck',
        'rates': <String, Object>{
          'base_fare': '300.00',
          'per_km': '25.00',
          'initial_minimum': '800.00',
        },
      }),
    ].map(customerVehicleFromCategory).toList(growable: false);

    expect(
      vehiclesForBookingFamily(vehicles, ServiceFamily.twoWheeler)
          .map((MockVehicle vehicle) => vehicle.name),
      <String>['City Ride'],
    );
    expect(
      vehiclesForBookingFamily(vehicles, ServiceFamily.threeWheeler)
          .map((MockVehicle vehicle) => vehicle.name),
      <String>['City Loader'],
    );
    expect(
      vehiclesForBookingFamily(vehicles, ServiceFamily.truck)
          .map((MockVehicle vehicle) => vehicle.name),
      <String>['Haul'],
    );

    seedRoute(km: 10);
    final MockLocation pickup = draft().pickup!;
    final MockLocation drop = draft().drop!;
    notifier.setReceiver(name: 'Asha', mobile: '9876543210');

    notifier.setVehicle(vehicles[0]);
    expect(draft().fareQuote.baseFare, 55);
    expect(draft().fareQuote.perKmCharge, 6);
    expect(draft().fareQuote.waitingCharge, 0);
    expect(draft().fareQuote.distanceKm, 10);
    expect(draft().estimatedFare, 115);

    notifier.setVehicle(vehicles[1]);
    expect(draft().estimatedFare, 225);
    expect(draft().fareQuote.surgeCharge, 15);
    expect(draft().pickup?.id, pickup.id);
    expect(draft().drop?.id, drop.id);
    expect(draft().receiverName, 'Asha');
    expect(draft().receiverMobile, '9876543210');

    notifier.setVehicle(vehicles[2]);
    expect(draft().fareQuote.distanceCharge, 250);
    expect(draft().estimatedFare, 800);
    expect(draft().pickup?.id, pickup.id);
    expect(draft().drop?.id, drop.id);
  });

  test('a new home booking clears temporary stops and keeps saved addresses', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'iu_saved_addresses_v1': jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'id': 'loc_user_1',
          'label': 'Home',
          'address': 'Real street 1',
          'latitude': 19.1,
          'longitude': 72.8,
        },
      ]),
    });
    notifier.setDeviceLocation(gps);
    notifier.setPickup(place);
    notifier.setDrop(
      const MockLocation(
        id: 'drop_pin',
        label: 'Bopal',
        address: 'Bopal, Ahmedabad',
        latitude: 23.03,
        longitude: 72.47,
      ),
    );
    notifier.setReceiver(name: 'Asha', mobile: '9876543210');
    notifier.setVehicle(scooty());
    notifier.applyRouteResult(
      signature: draft().currentRouteKey,
      distanceKm: 4,
      durationSeconds: 600,
    );

    notifier.beginNewBooking();

    expect(draft().pickup, isNull);
    expect(draft().drop, isNull);
    expect(draft().receiverName, isEmpty);
    expect(draft().receiverMobile, isEmpty);
    expect(draft().vehicle, isNull);
    expect(draft().routeDistanceKm, isNull);
    expect(draft().deviceLocation?.id, 'device_gps');
    expect(draft().deviceLocation?.latitude, gps.latitude);

    final SavedAddressesNotifier saved =
        container.read(savedAddressesProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    expect(saved.state.addresses.map((MockLocation item) => item.id), <String>[
      'loc_user_1',
    ]);
  });

  testWidgets('summary keeps the receiver and the route fare', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    seedRoute(km: 10);
    notifier.setVehicle(scooty(base: 50, perKm: 10));
    notifier.setReceiver(name: 'Asha', mobile: '9876543210');

    // Local FareEngine estimate is ₹150 (50 + 10×10). Seed a distinct
    // backend netPayable so the summary must use the authoritative quote.
    const double backendNetPayable = 160;
    expect(draft().estimatedFare, 150);
    expect(draft().estimatedFare, isNot(backendNetPayable));

    const ApiQuote backendQuote = ApiQuote(
      orderId: 'order-summary-test',
      displayId: 'IU-SUMMARY',
      fareQuoteId: 'fq-summary-test',
      tripFare: backendNetPayable,
      netPayable: backendNetPayable,
      distanceKm: 10,
      baseFare: 50,
      distanceCharge: 110,
    );
    container.read(backendQuoteHoldProvider.notifier).state = BackendQuoteHold(
      orderId: backendQuote.orderId,
      quote: backendQuote,
      vehicleCategoryId: draft().vehicle!.id,
      bookingKey: draft().quoteBookingKey,
    );
    notifier.applyQuotedPayable(backendNetPayable);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BookingSummaryScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('Trip Fare'), findsOneWidget);
    expect(find.text('₹160'), findsWidgets);
    expect(find.text('₹150'), findsNothing);
    expect(find.text('Estimated Fare'), findsNothing);
    expect(find.textContaining('Fare - calculated'), findsNothing);
    expect(find.text('Base ₹50'), findsNothing);
  });
}

class _RebuildHost extends StatefulWidget {
  const _RebuildHost({required this.load, super.key});

  final Future<DisplayRoute?> Function(List<GeoPoint> points) load;

  @override
  State<_RebuildHost> createState() => _RebuildHostState();
}

class _RebuildHostState extends State<_RebuildHost> {
  int _tick = 0;

  void rebuild() => setState(() => _tick += 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('tick $_tick'),
        BookingRoutePreview(
          points: const <GeoPoint>[
            GeoPoint(latitude: 23.0115, longitude: 72.565),
            GeoPoint(latitude: 23.03, longitude: 72.472),
          ],
          loadRoute: widget.load,
        ),
      ],
    );
  }
}
