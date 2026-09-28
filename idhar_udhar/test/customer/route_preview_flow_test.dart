import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/routing/app_routes.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/core/state/recent_locations_provider.dart';
import 'package:idhar_udhar/customer/core/widgets/animated_primary_button.dart';
import 'package:idhar_udhar/customer/core/widgets/glass_text_field.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/drop_location_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/pickup_location_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/route_preview_screen.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/vehicle_selection_screen.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:idhar_udhar/shared/maps/google_maps_http.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const DisplayRoute roadRoute = DisplayRoute(
    points: <GeoPoint>[
      GeoPoint(latitude: 23.0115, longitude: 72.5650),
      GeoPoint(latitude: 23.08, longitude: 72.62),
      GeoPoint(latitude: 23.0300, longitude: 72.4720),
    ],
    distanceMeters: 12400,
    durationSeconds: 1500,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Finder field(String hint) {
    return find.byWidgetPredicate(
      (Widget widget) => widget is GlassTextField && widget.hint == hint,
    );
  }

  Future<void> confirmAddress(
    WidgetTester tester, {
    required String house,
    required String building,
  }) async {
    expect(find.text('Complete Your Address'), findsOneWidget);
    await tester.enterText(field('House / Flat / Floor / Office No.'), house);
    await tester.enterText(field('Building / Flat / Office Name'), building);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AnimatedPrimaryButton));
    await tester.pumpAndSettle();
  }

  testWidgets('pickup confirm opens drop once, drop confirm opens route preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        routesServiceProvider.overrideWithValue(
          _ScriptedRoutes(roadRoute),
        ),
        vehicleCategoryCatalogProvider.overrideWith(
          (ref) async => const <VehicleCategory>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.bookPickup,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.bookPickup,
          builder: (BuildContext context, GoRouterState state) {
            return const PickupLocationScreen();
          },
        ),
        GoRoute(
          path: AppRoutes.bookDrop,
          builder: (BuildContext context, GoRouterState state) {
            return const DropLocationScreen();
          },
        ),
        GoRoute(
          path: AppRoutes.bookRoute,
          builder: (BuildContext context, GoRouterState state) {
            return const RoutePreviewScreen();
          },
        ),
        GoRoute(
          path: AppRoutes.bookVehicle,
          builder: (BuildContext context, GoRouterState state) {
            return const VehicleSelectionScreen();
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    final MockLocation pickup = MockData.locations
        .firstWhere((MockLocation item) => item.id == 'loc_paldi');
    final MockLocation drop = MockData.locations
        .firstWhere((MockLocation item) => item.id == 'loc_bopal');
    await container.read(recentLocationsProvider.notifier).remember(pickup);
    await container.read(recentLocationsProvider.notifier).remember(drop);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paldi'));
    await tester.pumpAndSettle();
    await confirmAddress(tester, house: 'A-204', building: 'Sunrise Heights');

    expect(find.text('Drop Location'), findsOneWidget);
    expect(find.text('Complete Your Address'), findsNothing);
    final BookingDraft afterPickup = container.read(bookingDraftProvider);
    expect(afterPickup.pickupAddressConfirmed, isTrue);
    expect(afterPickup.pickup?.latitude, pickup.latitude);
    expect(afterPickup.pickup?.longitude, pickup.longitude);
    expect(find.byType(RoutePreviewScreen), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Bopal'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Bopal'));
    await tester.pumpAndSettle();
    await confirmAddress(tester, house: '12', building: 'Lake View');

    expect(find.text('Route Preview'), findsOneWidget);
    expect(find.text('Complete Your Address'), findsNothing);
    expect(find.text('12.4 km'), findsOneWidget);
    expect(find.text('Select on Map'), findsNothing);
    final BookingDraft preview = container.read(bookingDraftProvider);
    expect(preview.dropConfirmedAt(0), isTrue);
    expect(preview.readyForRoutePreview, isTrue);
    expect(preview.drop?.latitude, drop.latitude);
    expect(preview.drop?.longitude, drop.longitude);
    expect(preview.routeDistanceMeters, roadRoute.distanceMeters);
    expect(find.text(roadRoute.distanceLabel), findsOneWidget);
    expect(
      find.text('A-204, Sunrise Heights, Paldi Cross Road, Ahmedabad'),
      findsWidgets,
    );
    expect(
      find.text('12, Lake View, Bopal, Ahmedabad'),
      findsWidgets,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(RoutePreviewScreen),
        matching: find.byType(AnimatedPrimaryButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select Vehicle'), findsOneWidget);
    expect(find.text('Route Preview'), findsNothing);
    expect(container.read(bookingDraftProvider).pickup?.latitude, pickup.latitude);
    expect(container.read(bookingDraftProvider).drop?.latitude, drop.latitude);
  });

  testWidgets('returning without changing pickup does not confirm the address again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        routesServiceProvider.overrideWithValue(_ScriptedRoutes(roadRoute)),
      ],
    );
    addTearDown(container.dispose);
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.bookPickup,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.bookPickup,
          builder: (BuildContext context, GoRouterState state) {
            return const PickupLocationScreen();
          },
        ),
        GoRoute(
          path: AppRoutes.bookDrop,
          builder: (BuildContext context, GoRouterState state) {
            return const DropLocationScreen();
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    final MockLocation pickup = MockData.locations
        .firstWhere((MockLocation item) => item.id == 'loc_paldi');
    await container.read(recentLocationsProvider.notifier).remember(pickup);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paldi'));
    await tester.pumpAndSettle();
    await confirmAddress(tester, house: 'A-204', building: 'Sunrise Heights');
    expect(find.text('Drop Location'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Pickup Location'), findsOneWidget);
    expect(find.text('Complete Your Address'), findsNothing);

    await tester.tap(find.byType(AnimatedPrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Drop Location'), findsOneWidget);
    expect(find.text('Complete Your Address'), findsNothing);
    expect(container.read(bookingDraftProvider).pickupAddressConfirmed, isTrue);
  });

  testWidgets('a missing routes result shows no invented distance', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        routesServiceProvider.overrideWithValue(_ScriptedRoutes(null)),
      ],
    );
    addTearDown(container.dispose);
    final BookingDraftNotifier notifier =
        container.read(bookingDraftProvider.notifier);
    final MockLocation pickup = MockData.locations
        .firstWhere((MockLocation item) => item.id == 'loc_paldi');
    final MockLocation drop = MockData.locations
        .firstWhere((MockLocation item) => item.id == 'loc_bopal');
    notifier.confirmPickupAddress(pickup.copyWith(unit: 'A-204', premises: 'Sunrise Heights'));
    notifier.confirmDropAddress(drop.copyWith(unit: '12', premises: 'Lake View'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoutePreviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final double straightKm = GeoMath.haversineKm(
      lat1: pickup.latitude!,
      lng1: pickup.longitude!,
      lat2: drop.latitude!,
      lng2: drop.longitude!,
    );
    expect(find.byKey(const Key('route-preview-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('route-preview-distance')), findsNothing);
    expect(find.text('${straightKm.toStringAsFixed(1)} km'), findsNothing);
    expect(find.textContaining('km'), findsNothing);
    expect(container.read(bookingDraftProvider).routeDistanceMeters, isNull);
    expect(container.read(bookingDraftProvider).pickup?.latitude, pickup.latitude);
    expect(container.read(bookingDraftProvider).drop?.longitude, drop.longitude);
  });

  testWidgets('shown distance is the routes result, not the point spacing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const DisplayRoute shortRoute = DisplayRoute(
      points: <GeoPoint>[
        GeoPoint(latitude: 23.0115, longitude: 72.5650),
        GeoPoint(latitude: 21.1418, longitude: 72.7709),
      ],
      distanceMeters: 850,
      durationSeconds: 180,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        routesServiceProvider.overrideWithValue(_ScriptedRoutes(shortRoute)),
      ],
    );
    addTearDown(container.dispose);
    final BookingDraftNotifier notifier =
        container.read(bookingDraftProvider.notifier);
    notifier.confirmPickupAddress(
      MockData.locations
          .firstWhere((MockLocation item) => item.id == 'loc_paldi')
          .copyWith(unit: 'A-204', premises: 'Sunrise Heights'),
    );
    notifier.confirmDropAddress(
      MockData.locations
          .firstWhere((MockLocation item) => item.id == 'loc_vesu')
          .copyWith(unit: '4', premises: 'Shop'),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoutePreviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('850 m'), findsOneWidget);
    expect(find.textContaining('km'), findsNothing);
    expect(
      container.read(bookingDraftProvider).routeDistanceMeters,
      shortRoute.distanceMeters,
    );
    expect(find.text(shortRoute.distanceLabel), findsOneWidget);
  });
}

class _ScriptedRoutes extends RoutesService {
  _ScriptedRoutes(this.result) : super(GoogleMapsHttp(MapsPlatform()));

  final DisplayRoute? result;

  @override
  Future<DisplayRoute?> compute({
    required GeoPoint origin,
    required GeoPoint destination,
    List<GeoPoint> intermediates = const <GeoPoint>[],
  }) async {
    return result;
  }
}
