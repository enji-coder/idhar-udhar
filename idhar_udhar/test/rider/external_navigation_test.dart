import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/rider/data/dummy/dummy_rider_repository.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/features/orders/external_navigation.dart';
import 'package:idhar_udhar/rider/routing/rider_routes.dart';
import 'package:idhar_udhar/rider/screens/orders/active_delivery_screen.dart';
import 'package:idhar_udhar/rider/screens/orders/order_details_screen.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<Uri> launched = <Uri>[];

  setUp(() {
    launched.clear();
    externalMapLauncher = (Uri uri) async {
      launched.add(uri);
      return true;
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall call) async {
        if (call.method == 'checkPermissionStatus') {
          return 0;
        }
        if (call.method == 'requestPermissions') {
          final List<dynamic> requested = call.arguments as List<dynamic>;
          return <int, int>{
            for (final dynamic value in requested) value as int: 0,
          };
        }
        return null;
      },
    );
  });

  tearDown(() {
    externalMapLauncher = launchExternalMapUrl;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
  });

  test('directions URL uses explicit coordinates and rejects invalid ones', () {
    final Uri? pickup = googleMapsDirectionsUri(
      latitude: 23.0225,
      longitude: 72.5714,
    );
    final Uri? drop = googleMapsDirectionsUri(
      latitude: 23.036,
      longitude: 72.561,
    );

    expect(pickup!.queryParameters['destination'], '23.0225,72.5714');
    expect(drop!.queryParameters['destination'], '23.036,72.561');
    expect(pickup.host, 'www.google.com');
    expect(pickup.path, '/maps/dir/');
    expect(pickup.queryParameters['api'], '1');
    expect(pickup.queryParameters.containsKey('query'), isFalse);
    expect(pickup.toString().contains('Pickup lane'), isFalse);

    expect(
      googleMapsDirectionsUri(latitude: null, longitude: 72.5714),
      isNull,
    );
    expect(
      googleMapsDirectionsUri(latitude: double.nan, longitude: 72.5714),
      isNull,
    );
    expect(
      googleMapsDirectionsUri(latitude: 23.0225, longitude: double.infinity),
      isNull,
    );
    expect(
      googleMapsDirectionsUri(latitude: 91, longitude: 72.5714),
      isNull,
    );
    expect(
      googleMapsDirectionsUri(latitude: 23.0225, longitude: 181),
      isNull,
    );
  });

  testWidgets('pickup navigation stays in the app and sends no status', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToPickup,
    );

    expect(find.text('ARRIVED AT PICKUP'), findsOneWidget);
    expect(find.text('Head to the pickup location'), findsOneWidget);
    expect(launched, isEmpty);
    expect(api.transitions, isEmpty);
    expect(api.gets, 0);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToPickup,
    );
  });

  testWidgets('drop navigation stays in the app and sends no status', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToDrop,
      order: _order(vehicleName: 'Scooty'),
    );

    expect(find.text('ARRIVED AT DROP LOCATION'), findsOneWidget);
    expect(find.text('Head to the drop location'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('vehicle-marker-scooter')), findsOneWidget);
    expect(launched, isEmpty);
    expect(api.transitions, isEmpty);
    expect(api.gets, 0);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
  });

  testWidgets('invalid coordinates do not launch a URL', (tester) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToPickup,
      order: _order(pickupLatitude: null, pickupLongitude: null),
    );
    await tester.pump();

    expect(launched, isEmpty);
    expect(
      find.text('This stop does not have usable coordinates.'),
      findsWidgets,
    );
    expect(api.transitions, isEmpty);
  });

  testWidgets('package pickup keeps drop navigation inside the app', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.packagePickedUp,
    );

    expect(find.text('START TRIP'), findsOneWidget);
    expect(launched, isEmpty);
    expect(api.transitions, isEmpty);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.packagePickedUp,
    );
  });

  testWidgets('Start Delivery opens pickup navigation and the active route', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    await _pumpDetails(tester, api: api);

    await tester.tap(find.text('Start Delivery'));
    await tester.pumpAndSettle();

    expect(launched, isEmpty);
    expect(find.text('Active delivery route'), findsOneWidget);
    expect(api.transitions, isEmpty);
    expect(api.gets, 0);
  });

  testWidgets('order details Navigate uses pickup coordinates only', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    await _pumpDetails(tester, api: api);

    await tester.ensureVisible(find.text('Navigate'));
    await tester.tap(find.text('Navigate'));
    await tester.pumpAndSettle();

    expect(launched, isEmpty);
    expect(find.text('Active delivery route'), findsOneWidget);
    expect(find.text('Navigation (demo)'), findsNothing);
    expect(api.transitions, isEmpty);
  });
}

Future<ProviderContainer> _pumpActive(
  WidgetTester tester, {
  required _ScriptedRiderApi api,
  required DeliveryLifecycleStatus status,
  RiderOrder? order,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      riderApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  container.read(activeOrderProvider.notifier).state = order ?? _order();
  container.read(deliveryStatusProvider.notifier).state = status;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ActiveDeliveryScreen()),
    ),
  );
  await tester.pump();
  return container;
}

Future<ProviderContainer> _pumpDetails(
  WidgetTester tester, {
  required _ScriptedRiderApi api,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      riderApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  container.read(activeOrderProvider.notifier).state = _order();

  final GoRouter router = GoRouter(
    initialLocation: RiderRoutes.orderDetails,
    routes: <RouteBase>[
      GoRoute(
        path: RiderRoutes.orderDetails,
        builder: (BuildContext context, GoRouterState state) {
          return const OrderDetailsScreen();
        },
      ),
      GoRoute(
        path: RiderRoutes.activeDelivery,
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Active delivery route'));
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
  return container;
}

class _ScriptedRiderApi extends RiderApi {
  _ScriptedRiderApi() : super(ApiClient(tokenStore: TokenStore()));

  final List<String> transitions = <String>[];
  int gets = 0;

  @override
  Future<ApiOrder> getOrder(String orderId) async {
    gets += 1;
    return _apiOrder('IN_TRANSIT');
  }

  @override
  Future<ApiOrder> transitionStatus({
    required String orderId,
    required String toStatus,
    String? reason,
  }) async {
    transitions.add(toStatus);
    return _apiOrder(toStatus);
  }
}

RiderOrder _order({
  double? pickupLatitude = 23.0225,
  double? pickupLongitude = 72.5714,
  double? dropLatitude = 23.036,
  double? dropLongitude = 72.561,
  String vehicleName = '',
}) {
  return RiderOrder(
    id: 'IU-1',
    backendOrderId: '11111111-1111-4111-8111-111111111111',
    pickup: 'Pickup lane',
    drop: 'Drop lane',
    distanceKm: 3,
    estimatedEarnings: 40,
    estimatedMinutes: 12,
    customerMaskedName: 'A.',
    customerMaskedPhone: '98XXXXXX10',
    vehicleName: vehicleName,
    pickupLatitude: pickupLatitude,
    pickupLongitude: pickupLongitude,
    dropLatitude: dropLatitude,
    dropLongitude: dropLongitude,
  );
}

ApiOrder _apiOrder(String status) {
  return ApiOrder(
    orderId: '11111111-1111-4111-8111-111111111111',
    displayId: 'IU-1',
    canonicalStatus: status,
    createdAt: DateTime.utc(2026, 10, 11),
  );
}
