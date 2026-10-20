import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/rider/data/dummy/dummy_rider_repository.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/features/orders/external_navigation.dart';
import 'package:idhar_udhar/rider/features/orders/rider_nav_overlay.dart';
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
    RiderNavSession.clear();
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
    RiderNavSession.clear();
    externalMapLauncher = launchExternalMapUrl;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('idhar_udhar/nav_overlay'),
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

  test('navigation URI uses the stop as destination and a separate origin', () {
    final Uri? turnByTurn = googleNavigationUri(
      latitude: 23.0225,
      longitude: 72.5714,
    );
    expect(turnByTurn.toString(), 'google.navigation:q=23.0225,72.5714&mode=d');
    expect(turnByTurn.toString().contains('origin'), isFalse);

    final Uri? samePoint = googleMapsDirectionsUri(
      latitude: 23.0225,
      longitude: 72.5714,
      originLatitude: 23.0225,
      originLongitude: 72.5714,
    );
    expect(samePoint!.queryParameters.containsKey('origin'), isFalse);

    final Uri? withOrigin = googleMapsDirectionsUri(
      latitude: 23.036,
      longitude: 72.561,
      originLatitude: 23.01,
      originLongitude: 72.55,
    );
    expect(withOrigin!.queryParameters['destination'], '23.036,72.561');
    expect(withOrigin.queryParameters['origin'], '23.01,72.55');
    expect(
      googleNavigationUri(latitude: null, longitude: 72.5714),
      isNull,
    );
  });

  test('pickup completion switches the next destination to drop', () {
    final RiderNavTarget? pickup = riderNavTargetFor(
      orderId: 'order-a',
      status: DeliveryLifecycleStatus.goingToPickup,
      pickupLatitude: 23.0225,
      pickupLongitude: 72.5714,
      dropLatitude: 23.036,
      dropLongitude: 72.561,
    );
    final RiderNavTarget? drop = riderNavTargetFor(
      orderId: 'order-a',
      status: DeliveryLifecycleStatus.goingToDrop,
      pickupLatitude: 23.0225,
      pickupLongitude: 72.5714,
      dropLatitude: 23.036,
      dropLongitude: 72.561,
    );
    final RiderNavTarget? nextOrder = riderNavTargetFor(
      orderId: 'order-b',
      status: DeliveryLifecycleStatus.goingToPickup,
      pickupLatitude: 22.5,
      pickupLongitude: 71.5,
      dropLatitude: 23.036,
      dropLongitude: 72.561,
    );

    expect(pickup!.toDrop, isFalse);
    expect(pickup.latitude, 23.0225);
    expect(drop!.toDrop, isTrue);
    expect(drop.latitude, 23.036);
    expect(nextOrder!.orderId, 'order-b');
    expect(nextOrder.latitude, 22.5);
    expect(nextOrder.longitude, isNot(pickup.longitude));
    expect(
      riderNavTargetFor(
        orderId: 'order-a',
        status: DeliveryLifecycleStatus.goingToPickup,
        pickupLatitude: 91,
        pickupLongitude: 72,
        dropLatitude: 23,
        dropLongitude: 72,
      ),
      isNull,
    );
    expect(
      riderNavTargetFor(
        orderId: 'order-a',
        status: DeliveryLifecycleStatus.arrivedAtPickup,
        pickupLatitude: 23,
        pickupLongitude: 72,
        dropLatitude: 23.1,
        dropLongitude: 72.1,
      ),
      isNull,
    );
  });

  test('navigation launch keeps GPS origin off the turn-by-turn intent', () {
    final RiderNavigationLaunch? launch = riderNavigationLaunch(
      destinationLatitude: 23.0225,
      destinationLongitude: 72.5714,
      originLatitude: 23.0301,
      originLongitude: 72.5802,
    );
    expect(
      launch!.navigation.toString(),
      'google.navigation:q=23.0225,72.5714&mode=d',
    );
    expect(launch.navigation.toString().contains('23.0301'), isFalse);
    expect(launch.fallback.queryParameters['destination'], '23.0225,72.5714');
    expect(launch.fallback.queryParameters['origin'], '23.0301,72.5802');
    expect(launch.fallback.queryParameters['origin'], isNot('23.0330,72.5660'));

    final RiderNavigationLaunch? noFix = riderNavigationLaunch(
      destinationLatitude: 23.0225,
      destinationLongitude: 72.5714,
    );
    expect(noFix!.fallback.queryParameters.containsKey('origin'), isFalse);
    expect(
      riderNavigationLaunch(
        destinationLatitude: null,
        destinationLongitude: 72.5714,
        originLatitude: 23.0301,
        originLongitude: 72.5802,
      ),
      isNull,
    );
  });

  test('overlay controls do not include status actions', () {
    for (final String action in <String>[
      'arrived_pickup',
      'start_trip',
      'arrived_drop',
      'receiver_unavailable',
      'delivered',
    ]) {
      expect(riderOverlayStatusAction(action), isTrue);
    }
    expect(riderOverlayStatusAction('order_details'), isFalse);
    expect(riderOverlayStatusAction('return_to_app'), isFalse);
    expect(riderOverlayStatusAction('dismiss'), isFalse);
    expect(riderOverlayShouldStop(DeliveryLifecycleStatus.delivered), isTrue);
    expect(
      riderOverlayShouldStop(DeliveryLifecycleStatus.receiverUnavailable),
      isTrue,
    );
    expect(
      riderOverlayShouldStop(DeliveryLifecycleStatus.parcelAtCompanyOffice),
      isTrue,
    );
    expect(
      riderOverlayShouldStop(DeliveryLifecycleStatus.goingToDrop),
      isFalse,
    );
  });

  test('prepared navigation launches turn-by-turn without a GPS wait', () async {
    final Stopwatch watch = Stopwatch()..start();
    final bool opened = await launchPreparedNavigation(
      Uri.parse('google.navigation:q=23.0225,72.5714&mode=d'),
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=23.0225,72.5714',
      ),
    );
    watch.stop();
    expect(opened, isTrue);
    expect(watch.elapsed, lessThan(navigationLaunchBudget));
    expect(lastNavigationLaunchElapsed, isNotNull);
    expect(lastNavigationLaunchElapsed!, lessThan(navigationLaunchBudget));
    expect(
      launched.single.toString(),
      'google.navigation:q=23.0225,72.5714&mode=d',
    );

    launched.clear();
    externalMapLauncher = (Uri uri) async {
      launched.add(uri);
      throw StateError('maps missing');
    };
    final bool failed = await launchPreparedNavigation(
      Uri.parse('google.navigation:q=1.0,2.0&mode=d'),
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=1.0,2.0'),
    );
    expect(failed, isFalse);
    expect(launched, hasLength(2));
  });

  test('a second navigation tap does not launch twice', () async {
    final NavLaunchGate gate = NavLaunchGate();
    var calls = 0;
    externalMapLauncher = (Uri uri) async {
      calls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return true;
    };
    final Future<bool> first = launchExternalNavigationUris(
      navigation: Uri.parse('google.navigation:q=1.0,2.0&mode=d'),
      fallback: null,
      gate: gate,
    );
    final bool second = await launchExternalNavigationUris(
      navigation: Uri.parse('google.navigation:q=1.0,2.0&mode=d'),
      fallback: null,
      gate: gate,
    );
    expect(second, isFalse);
    expect(await first, isTrue);
    expect(calls, 1);
  });

  test('launcher failure falls back once and a thrown launcher does not crash',
      () async {
    final NavLaunchGate gate = NavLaunchGate();
    final List<String> seen = <String>[];
    externalMapLauncher = (Uri uri) async {
      seen.add(uri.toString());
      if (uri.scheme == 'google.navigation') {
        return false;
      }
      return true;
    };
    final bool opened = await launchExternalNavigationUris(
      navigation: Uri.parse('google.navigation:q=1.0,2.0&mode=d'),
      fallback: Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=1.0,2.0',
      ),
      gate: gate,
    );
    expect(opened, isTrue);
    expect(seen, hasLength(2));

    externalMapLauncher = (Uri uri) async {
      throw StateError('unavailable');
    };
    expect(
      await launchExternalNavigationUris(
        navigation: Uri.parse('google.navigation:q=1.0,2.0&mode=d'),
        fallback: Uri.parse('https://www.google.com/maps/dir/?api=1'),
        gate: NavLaunchGate(),
      ),
      isFalse,
    );
  });

  test('overlay permission denied does not throw', () async {
    expect(await RiderNavOverlay.canDrawOverlays(), isFalse);
    await RiderNavOverlay.openOverlaySettings();
    await RiderNavOverlay.disarm();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('idhar_udhar/nav_overlay'),
      (MethodCall call) async {
        if (call.method == 'canDrawOverlays') {
          return false;
        }
        return null;
      },
    );
    expect(await RiderNavOverlay.canDrawOverlays(), isFalse);
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

    expect(find.text('ARRIVED AT PICKUP LOCATION'), findsOneWidget);
    expect(find.text('Pickup lane'), findsOneWidget);
    expect(find.text('Head to the pickup location'), findsNothing);
    expect(launched, isEmpty);

    await tester.tap(find.text('Start navigation to pickup'));
    await tester.pump();

    expect(launched, hasLength(1));
    expect(
      launched.single.toString(),
      'google.navigation:q=23.0225,72.5714&mode=d',
    );
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
    expect(find.text('Drop lane'), findsOneWidget);
    expect(find.text('Head to the drop location'), findsNothing);
    expect(launched, isEmpty);

    await tester.tap(find.text('Start navigation to drop'));
    await tester.pump();

    expect(launched, hasLength(1));
    expect(
      launched.single.toString(),
      'google.navigation:q=23.036,72.561&mode=d',
    );
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
      findsNothing,
    );

    await tester.tap(find.text('Start navigation to pickup'));
    await tester.pump();

    expect(launched, isEmpty);
    expect(
      find.text(externalNavigationCoordinatesMessage),
      findsOneWidget,
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

    await tester.tap(find.text('Start navigation to drop'));
    await tester.pump();

    expect(launched, hasLength(1));
    expect(
      launched.single.toString(),
      'google.navigation:q=23.036,72.561&mode=d',
    );
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

    expect(launched, hasLength(1));
    expect(
      launched.single.toString(),
      'google.navigation:q=23.0225,72.5714&mode=d',
    );
    expect(find.text('Active delivery route'), findsOneWidget);
    expect(api.transitions, isEmpty);
    expect(api.gets, 0);
  });

  testWidgets('order details Start Delivery stays in the app', (tester) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    await _pumpDetails(tester, api: api);

    expect(find.text('Navigate'), findsNothing);
    expect(find.text('Navigation (demo)'), findsNothing);
    expect(find.text('Pickup lane'), findsOneWidget);
    expect(find.text('Start Delivery'), findsOneWidget);
    expect(launched, isEmpty);

    await tester.tap(find.text('Start Delivery'));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(
      launched.single.toString(),
      'google.navigation:q=23.0225,72.5714&mode=d',
    );
    expect(find.text('Active delivery route'), findsOneWidget);
    expect(api.transitions, isEmpty);
    expect(api.gets, 0);
  });

  testWidgets('repeated navigation taps launch one maps intent',
      (tester) async {
    externalMapLauncher = (Uri uri) async {
      launched.add(uri);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return true;
    };
    await _pumpActive(
      tester,
      api: _ScriptedRiderApi(),
      status: DeliveryLifecycleStatus.goingToPickup,
    );

    await tester.tap(find.text('Start navigation to pickup'));
    await tester.tap(find.text('Start navigation to pickup'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Start navigation to pickup'));
    await tester.pump();

    expect(launched, hasLength(1));
  });

  testWidgets('pickup completion opens drop navigation once', (tester) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'PICKED_UP';
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.packagePickedUp,
    );

    await tester.tap(find.text('START TRIP'));
    await tester.pump();
    await tester.pump();

    expect(api.transitions, <String>['IN_TRANSIT']);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
    expect(launched, hasLength(1));
    expect(
      launched.single.toString(),
      'google.navigation:q=23.036,72.561&mode=d',
    );

    await tester.tap(find.text('Start navigation to drop'));
    await tester.pump();
    expect(launched, hasLength(1));
  });

  testWidgets('overlay arrival uses the existing pickup handler',
      (tester) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'EN_ROUTE_PICKUP';
    await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToPickup,
    );

    await _sendOverlayAction(tester, 'arrived_drop');
    expect(api.transitions, isEmpty);

    await _sendOverlayAction(tester, 'arrived_pickup');
    await _sendOverlayAction(tester, 'start_trip');
    await _sendOverlayAction(tester, 'arrived_drop');
    await tester.pump();

    expect(api.transitions, isEmpty);
    expect(find.text('ARRIVED AT PICKUP LOCATION'), findsOneWidget);
  });

  testWidgets('overlay hides when the delivery ends or is dismissed', (
    tester,
  ) async {
    final List<String> methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('idhar_udhar/nav_overlay'),
      (MethodCall call) async {
        methods.add(call.method);
        return null;
      },
    );
    final ProviderContainer container = await _pumpActive(
      tester,
      api: _ScriptedRiderApi(),
      status: DeliveryLifecycleStatus.goingToPickup,
    );
    await tester.tap(find.text('Start navigation to pickup'));
    await tester.pump();
    methods.clear();

    container.read(deliveryStatusProvider.notifier).state =
        DeliveryLifecycleStatus.delivered;
    await tester.pump();
    expect(methods, contains('disarm'));

    methods.clear();
    container.read(deliveryStatusProvider.notifier).state =
        DeliveryLifecycleStatus.goingToDrop;
    await tester.pump();
    await tester.tap(find.text('Start navigation to drop'));
    await tester.pump();
    methods.clear();
    await _sendOverlayAction(tester, 'dismiss');
    await tester.pump();
    expect(methods, contains('disarm'));
  });

  test('overlay window stays hidden while the app activity is started', () {
    expect(
      riderOverlayWindowVisible(
        deliveryArmed: true,
        appInBackground: false,
        anyAppActivityStarted: true,
        permissionGranted: true,
        dismissed: false,
      ),
      isFalse,
    );
    expect(
      riderOverlayWindowVisible(
        deliveryArmed: true,
        appInBackground: true,
        anyAppActivityStarted: true,
        permissionGranted: true,
        dismissed: false,
      ),
      isFalse,
    );
    expect(
      riderOverlayWindowVisible(
        deliveryArmed: true,
        appInBackground: true,
        anyAppActivityStarted: false,
        permissionGranted: true,
        dismissed: false,
      ),
      isTrue,
    );
    expect(
      riderOverlayWindowVisible(
        deliveryArmed: false,
        appInBackground: true,
        anyAppActivityStarted: false,
        permissionGranted: true,
        dismissed: false,
      ),
      isFalse,
    );
    expect(
      riderOverlayWindowVisible(
        deliveryArmed: true,
        appInBackground: true,
        anyAppActivityStarted: false,
        permissionGranted: false,
        dismissed: false,
      ),
      isFalse,
    );
    expect(riderBubbleTapAction(dragged: true), isNull);
    expect(riderBubbleTapAction(dragged: false), 'return_to_app');
    expect(
      riderOverlayControlAction(control: 'bubble', dragged: true),
      isNull,
    );
    expect(
      riderOverlayControlAction(control: 'options_menu', dragged: false),
      'options_menu',
    );
    expect(
      riderOverlayControlAction(control: 'close', dragged: false),
      'dismiss',
    );
    expect(
      riderOverlayControlAction(control: 'options_menu', dragged: true),
      isNull,
    );
    expect(
      riderOverlayWindowVisible(
        deliveryArmed: true,
        appInBackground: true,
        anyAppActivityStarted: false,
        permissionGranted: true,
        dismissed: true,
      ),
      isFalse,
    );
  });

  testWidgets('foreground hides the overlay and preserves delivery status', (
    tester,
  ) async {
    final List<String> methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('idhar_udhar/nav_overlay'),
      (MethodCall call) async {
        methods.add(call.method);
        if (call.method == 'canDrawOverlays') {
          return true;
        }
        return null;
      },
    );
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'EN_ROUTE_PICKUP';
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToPickup,
    );
    expect(methods, contains('arm'));
    expect(methods, isNot(contains('background')));

    methods.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(methods, isEmpty);
    expect(api.transitions, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(methods, contains('background'));
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToPickup,
    );

    methods.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(methods, contains('foreground'));
    expect(find.text('ARRIVED AT PICKUP LOCATION'), findsOneWidget);
    expect(api.transitions, isEmpty);

    await _sendOverlayAction(tester, 'return_to_app');
    expect(api.transitions, isEmpty);
    expect(find.text('ARRIVED AT PICKUP LOCATION'), findsOneWidget);
  });

  testWidgets('icon return leaves the same delivery screen unchanged', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'EN_ROUTE_PICKUP';
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToPickup,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await _sendOverlayAction(tester, 'return_to_app');
    await _sendOverlayAction(tester, 'arrived_pickup');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(api.transitions, isEmpty);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToPickup,
    );
    expect(find.text('ARRIVED AT PICKUP LOCATION'), findsOneWidget);
    expect(find.text('Rider at Pickup'), findsNothing);
  });

  testWidgets('options menu opens existing order details then returns', (
    tester,
  ) async {
    final List<String> methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('idhar_udhar/nav_overlay'),
      (MethodCall call) async {
        methods.add(call.method);
        return null;
      },
    );
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'EN_ROUTE_PICKUP';
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToPickup,
    );

    await _sendOverlayAction(tester, 'order_details');
    await tester.pumpAndSettle();

    expect(find.text('Order details'), findsOneWidget);
    expect(find.text('Pickup lane'), findsWidgets);
    expect(find.text('Drop lane'), findsWidgets);
    expect(find.text('Trip fare'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Sender'), findsOneWidget);
    expect(find.text('Receiver'), findsOneWidget);
    expect(api.transitions, isEmpty);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToPickup,
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(methods, isNot(contains('moveToBack')));
    expect(find.text('ARRIVED AT PICKUP LOCATION'), findsOneWidget);
    expect(find.text('Order details'), findsNothing);
    expect(api.transitions, isEmpty);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToPickup,
    );
  });

  testWidgets('closing the bubble does not cancel or return until navigation', (
    tester,
  ) async {
    final List<String> methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('idhar_udhar/nav_overlay'),
      (MethodCall call) async {
        methods.add(call.method);
        return null;
      },
    );
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'EN_ROUTE_PICKUP';
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToPickup,
    );
    await tester.tap(find.text('Start navigation to pickup'));
    await tester.pump();
    methods.clear();

    await _sendOverlayAction(tester, 'dismiss');
    await tester.pump();
    expect(methods, contains('disarm'));
    expect(api.transitions, isEmpty);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToPickup,
    );

    methods.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(methods, isNot(contains('arm')));
    expect(methods, isNot(contains('background')));
    expect(api.transitions, isEmpty);

    await tester.tap(find.text('Start navigation to pickup'));
    await tester.pump();
    expect(methods, contains('arm'));
    expect(api.transitions, isEmpty);
  });

  test('server status restores the current phase and never an earlier one', () {
    expect(
      restoredDeliveryPhase(
        local: DeliveryLifecycleStatus.accepted,
        canonicalStatus: 'IN_TRANSIT',
      ),
      DeliveryLifecycleStatus.goingToDrop,
    );
    expect(
      restoredDeliveryPhase(
        local: DeliveryLifecycleStatus.goingToDrop,
        canonicalStatus: 'EN_ROUTE_PICKUP',
      ),
      isNull,
    );
    expect(
      restoredDeliveryPhase(
        local: DeliveryLifecycleStatus.arrivedAtPickup,
        canonicalStatus: 'ARRIVED_PICKUP',
      ),
      DeliveryLifecycleStatus.arrivedAtPickup,
    );
    expect(
      restoredDeliveryPhase(
        local: DeliveryLifecycleStatus.goingToPickup,
        canonicalStatus: 'NOT_A_STATUS',
      ),
      isNull,
    );
    expect(
      shouldResumeActiveDelivery(
        handoffActive: true,
        status: DeliveryLifecycleStatus.accepted,
        hasOrder: true,
        onOrderDetails: true,
      ),
      isTrue,
    );
    expect(
      shouldResumeActiveDelivery(
        handoffActive: false,
        status: DeliveryLifecycleStatus.accepted,
        hasOrder: true,
        onOrderDetails: true,
      ),
      isFalse,
    );
    expect(
      shouldResumeActiveDelivery(
        handoffActive: false,
        status: DeliveryLifecycleStatus.goingToDrop,
        hasOrder: true,
        onOrderDetails: true,
      ),
      isTrue,
    );
    expect(riderServerDropArrival('NEAR_DROP'), isTrue);
    expect(riderServerDropArrival('IN_TRANSIT'), isFalse);
  });

  testWidgets('return at each phase shows that phase and launches nothing', (
    tester,
  ) async {
    Future<void> resumeAt({
      required DeliveryLifecycleStatus status,
      required String serverStatus,
      required String visible,
    }) async {
      final _ScriptedRiderApi api = _ScriptedRiderApi()
        ..serverStatus = serverStatus;
      final ProviderContainer container = await _pumpActive(
        tester,
        api: api,
        status: status,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await _sendOverlayAction(tester, 'return_to_app');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(visible), findsOneWidget);
      expect(container.read(deliveryStatusProvider), status);
      expect(api.transitions, isEmpty);
      expect(launched, isEmpty);
    }

    await resumeAt(
      status: DeliveryLifecycleStatus.goingToPickup,
      serverStatus: 'EN_ROUTE_PICKUP',
      visible: 'ARRIVED AT PICKUP LOCATION',
    );
    await resumeAt(
      status: DeliveryLifecycleStatus.arrivedAtPickup,
      serverStatus: 'ARRIVED_PICKUP',
      visible: 'Package Picked Up',
    );
    await resumeAt(
      status: DeliveryLifecycleStatus.packagePickedUp,
      serverStatus: 'PICKED_UP',
      visible: 'START TRIP',
    );
    await resumeAt(
      status: DeliveryLifecycleStatus.goingToDrop,
      serverStatus: 'IN_TRANSIT',
      visible: 'ARRIVED AT DROP LOCATION',
    );
  });

  testWidgets('a stale server status does not move the drop screen backward', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'EN_ROUTE_PICKUP';
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToDrop,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('ARRIVED AT DROP LOCATION'), findsOneWidget);
    expect(find.text('Receiver not available?'), findsOneWidget);
    expect(find.text('View Details'), findsNothing);
    expect(find.text('ARRIVED AT PICKUP LOCATION'), findsNothing);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
    expect(api.transitions, isEmpty);
    expect(launched, isEmpty);
  });

  testWidgets('resume applies a later server phase without launching maps', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'IN_TRANSIT';
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.accepted,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('ARRIVED AT DROP LOCATION'), findsOneWidget);
    expect(find.text('Receiver not available?'), findsOneWidget);
    expect(find.text('View Details'), findsNothing);
    expect(find.text('ARRIVED AT PICKUP LOCATION'), findsNothing);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
    expect(api.transitions, isEmpty);
    expect(launched, isEmpty);

    await tester.tap(find.text('Receiver not available?'));
    await tester.pumpAndSettle();
    expect(find.text('Receiver Unavailable'), findsOneWidget);
    expect(api.transitions, isEmpty);
  });

  testWidgets('drop arrival restores the delivered action', (tester) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'NEAR_DROP';
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToDrop,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Mark as Delivered'), findsOneWidget);
    expect(find.text('ARRIVED AT PICKUP LOCATION'), findsNothing);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
    expect(api.transitions, isEmpty);
    expect(launched, isEmpty);
  });

  testWidgets('options close returns to the drop screen', (tester) async {
    final List<String> methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('idhar_udhar/nav_overlay'),
      (MethodCall call) async {
        methods.add(call.method);
        return null;
      },
    );
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'IN_TRANSIT';
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToDrop,
    );

    await _sendOverlayAction(tester, 'order_details');
    await tester.pumpAndSettle();
    expect(find.text('Order details'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(methods, isNot(contains('moveToBack')));
    expect(find.text('ARRIVED AT DROP LOCATION'), findsOneWidget);
    expect(find.text('Receiver not available?'), findsOneWidget);
    expect(find.text('View Details'), findsNothing);
    expect(find.text('Order details'), findsNothing);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
    expect(api.transitions, isEmpty);
    expect(launched, isEmpty);
  });

  testWidgets('start trip navigates to drop and returning does not relaunch', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'ARRIVED_PICKUP';
    final ProviderContainer container = await _pumpActive(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.arrivedAtPickup,
    );

    await tester.tap(find.text('Package Picked Up'));
    await tester.pumpAndSettle();

    expect(api.transitions, <String>['PICKED_UP', 'IN_TRANSIT']);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
    expect(launched, hasLength(1));
    expect(
      launched.single.toString(),
      'google.navigation:q=23.036,72.561&mode=d',
    );

    api.serverStatus = 'IN_TRANSIT';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await _sendOverlayAction(tester, 'return_to_app');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(find.text('ARRIVED AT DROP LOCATION'), findsOneWidget);
    expect(api.transitions, <String>['PICKED_UP', 'IN_TRANSIT']);
  });

  testWidgets('returning from order details restores the server phase screen', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'IN_TRANSIT';
    final ProviderContainer container = await _pumpDetails(
      tester,
      api: api,
      liveDelivery: true,
    );
    container.read(deliveryStatusProvider.notifier).state =
        DeliveryLifecycleStatus.accepted;
    RiderNavSession.noteHandoff();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('ARRIVED AT DROP LOCATION'), findsOneWidget);
    expect(find.text('Start Delivery'), findsNothing);
    expect(api.transitions, isEmpty);
    expect(launched, isEmpty);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
  });

  testWidgets('order details stays put before a delivery handoff', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..serverStatus = 'ASSIGNED';
    await _pumpDetails(tester, api: api, liveDelivery: true);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Start Delivery'), findsOneWidget);
    expect(find.text('ARRIVED AT PICKUP LOCATION'), findsNothing);
    expect(api.transitions, isEmpty);
    expect(launched, isEmpty);
  });
}

Future<void> _sendOverlayAction(WidgetTester tester, String action) async {
  final ByteData data = const StandardMethodCodec().encodeMethodCall(
    MethodCall('onAction', action),
  );
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'idhar_udhar/nav_overlay',
    data,
    (ByteData? _) {},
  );
  await tester.pump();
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
  bool liveDelivery = false,
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
          if (liveDelivery) {
            return const ActiveDeliveryScreen();
          }
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
  String serverStatus = 'IN_TRANSIT';

  @override
  Future<ApiOrder> getOrder(String orderId) async {
    gets += 1;
    return _apiOrder(serverStatus);
  }

  @override
  Future<ApiOrderPaymentView?> getOrderPayment(String orderId) async {
    return null;
  }

  @override
  Future<PickupWaitSnapshot> getPickupWait(String orderId) async {
    return PickupWaitSnapshot(
      arrivalAt: DateTime.utc(2026, 10, 19, 10),
      pickedUpAt: null,
      serverNow: DateTime.utc(2026, 10, 19, 10, 1),
      timestampStatus: 'ok',
      initialWaitingMinutes: 5,
      perMinute: '1.00',
      elapsedSeconds: 0,
      elapsedMinutes: 0,
      chargeableMinutes: 0,
      amount: '0.00',
      amountSource: 'preview',
      vehicleCategoryName: '',
    );
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
