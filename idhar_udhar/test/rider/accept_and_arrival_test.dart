import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/rider/data/dummy/dummy_rider_repository.dart';
import 'package:idhar_udhar/rider/data/models/rider_earnings.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/push/rider_accept_flow.dart';
import 'package:idhar_udhar/rider/routing/rider_routes.dart';
import 'package:idhar_udhar/rider/screens/dashboard/rider_dashboard_screen.dart';
import 'package:idhar_udhar/rider/screens/orders/active_delivery_screen.dart';
import 'package:idhar_udhar/rider/screens/orders/incoming_order_screen.dart';
import 'package:idhar_udhar/rider/screens/orders/order_details_screen.dart';
import 'package:idhar_udhar/rider/state/rider_session.dart';
import 'package:idhar_udhar/rider/widgets/rider_order_alert.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/notifications_api.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/profiles_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';

const String _orderId = '11111111-1111-4111-8111-111111111111';
const String _offerId = '22222222-2222-4222-8222-222222222222';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('popup accept opens order details once after confirmation', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    final ProviderContainer container = _container(api);
    addTearDown(container.dispose);
    final GoRouter router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(container, router));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.accepts, 1);
    expect(find.text('Start Delivery'), findsOneWidget);
    expect(find.text('Order Accepted!'), findsNothing);
    expect(container.read(activeOrderProvider)?.backendOrderId, _orderId);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.accepted,
    );
  });

  testWidgets('popup accept failure stays on the offer', (tester) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..failAccept = true;
    final ProviderContainer container = _container(api);
    addTearDown(container.dispose);
    final GoRouter router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(container, router));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.accepts, 1);
    expect(find.text('This order offer expired.'), findsOneWidget);
    expect(find.text('Accept'), findsWidgets);
    expect(find.text('Start Delivery'), findsNothing);
    expect(container.read(activeOrderProvider), isNull);
  });

  testWidgets('full-screen accept opens order details once', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    final ProviderContainer container = _container(api);
    addTearDown(container.dispose);
    final GoRouter router = _router(initial: RiderRoutes.incomingOrder);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(container, router));
    await tester.pump();
    await tester.pump();

    expect(find.text('Accept'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump();

    expect(api.accepts, 1);
    expect(find.text('Start Delivery'), findsOneWidget);
    expect(find.text('Order Accepted!'), findsNothing);
  });

  testWidgets('full-screen accept failure stays on the offer', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _ScriptedRiderApi api = _ScriptedRiderApi()..failAccept = true;
    final ProviderContainer container = _container(api);
    addTearDown(container.dispose);
    final GoRouter router = _router(initial: RiderRoutes.incomingOrder);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(container, router));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump();

    expect(api.accepts, 1);
    expect(find.text('This order offer expired.'), findsOneWidget);
    expect(find.text('Start Delivery'), findsNothing);
  });

  testWidgets('dashboard accept opens order details once', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    final ProviderContainer container = _container(api);
    addTearDown(container.dispose);
    final GoRouter router = _router(
      initial: RiderRoutes.dashboard,
      dashboard: const RiderDashboardScreen(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(container, router));
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('Accept'));
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump();

    expect(api.accepts, 1);
    expect(find.text('Start Delivery'), findsOneWidget);
    expect(find.text('Order Accepted!'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('order details back reaches the dashboard after replacement', (
    tester,
  ) async {
    final ProviderContainer container = _container(_ScriptedRiderApi());
    addTearDown(container.dispose);
    container.read(activeOrderProvider.notifier).state = OrderMapper.toRiderOrder(
      offer: _offer(),
    );
    final GoRouter router = _router(initial: RiderRoutes.orderDetails);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(container, router));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump();
    expect(find.text('Rider dashboard'), findsOneWidget);
  });

  testWidgets('ARRIVED AT PICKUP records both legal hops', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    final ProviderContainer container = _container(api);
    addTearDown(container.dispose);
    container.read(activeOrderProvider.notifier).state = OrderMapper.toRiderOrder(
      offer: _offer(),
    );
    container.read(deliveryStatusProvider.notifier).state =
        DeliveryLifecycleStatus.accepted;
    final GoRouter router = _router(initial: RiderRoutes.activeDelivery);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(container, router));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('ARRIVED AT PICKUP'));
    await tester.pump();
    await tester.pump();

    expect(api.transitions, <String>['EN_ROUTE_PICKUP', 'ARRIVED_PICKUP']);
    expect(find.byKey(const Key('waiting-clock')), findsOneWidget);
  });

  testWidgets('a failed first hop does not arrive or open waiting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _ScriptedRiderApi api = _ScriptedRiderApi()..failFirstHop = true;
    final ProviderContainer container = _container(api);
    addTearDown(container.dispose);
    container.read(activeOrderProvider.notifier).state = OrderMapper.toRiderOrder(
      offer: _offer(),
    );
    container.read(deliveryStatusProvider.notifier).state =
        DeliveryLifecycleStatus.accepted;
    final GoRouter router = _router(initial: RiderRoutes.activeDelivery);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(container, router));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('ARRIVED AT PICKUP'));
    await tester.pump();
    await tester.pump();

    expect(api.transitions, <String>['EN_ROUTE_PICKUP']);
    expect(find.byKey(const Key('waiting-clock')), findsNothing);
    expect(find.textContaining('EN_ROUTE_PICKUP'), findsOneWidget);
  });
}

class _PopupHost extends ConsumerWidget {
  const _PopupHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RiderOffer offer = _offer();
    return Scaffold(
      body: TextButton(
        onPressed: () async {
          String? route;
          await RiderOrderAlert.show(
            context,
            order: OrderMapper.toRiderOrder(offer: offer),
            onAccept: () async {
              try {
                final RiderOrder accepted = await loadOrderAfterAccept(
                  api: ref.read(riderApiProvider),
                  offer: offer,
                );
                route = await publishAcceptedOrder(ref: ref, order: accepted);
                return null;
              } on ApiException catch (error) {
                return error.message;
              }
            },
            onReject: () async => null,
          );
          if (route != null && context.mounted) {
            context.go(route!);
          }
        },
        child: const Text('open'),
      ),
    );
  }
}

Widget _app(ProviderContainer container, GoRouter router) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

ProviderContainer _container(_ScriptedRiderApi api) {
  return ProviderContainer(
    overrides: <Override>[
      riderApiProvider.overrideWithValue(api),
      walletApiProvider.overrideWithValue(_QuietWallet()),
      profilesApiProvider.overrideWithValue(_QuietProfiles()),
      notificationsApiProvider.overrideWithValue(_QuietNotices()),
      riderOnlineProvider.overrideWith((Ref ref) => true),
      riderApiEarningsProvider.overrideWith(
        (Ref ref) async => RiderEarnings.empty,
      ),
      riderSessionProvider.overrideWith(
        (Ref ref) => _SeededSession(ref),
      ),
    ],
  );
}

GoRouter _router({
  String initial = '/open',
  Widget dashboard = const Scaffold(body: Text('Rider dashboard')),
}) {
  return GoRouter(
    initialLocation: initial,
    routes: <RouteBase>[
      GoRoute(
        path: '/open',
        builder: (BuildContext context, GoRouterState state) {
          return const _PopupHost();
        },
      ),
      GoRoute(
        path: RiderRoutes.incomingOrder,
        builder: (BuildContext context, GoRouterState state) {
          return const IncomingOrderScreen();
        },
      ),
      GoRoute(
        path: RiderRoutes.dashboard,
        builder: (BuildContext context, GoRouterState state) {
          return dashboard;
        },
      ),
      GoRoute(
        path: RiderRoutes.orderDetails,
        builder: (BuildContext context, GoRouterState state) {
          return const OrderDetailsScreen();
        },
      ),
      GoRoute(
        path: RiderRoutes.activeDelivery,
        builder: (BuildContext context, GoRouterState state) {
          return const ActiveDeliveryScreen();
        },
      ),
    ],
  );
}

class _SeededSession extends RiderSessionNotifier {
  _SeededSession(super.ref) {
    state = const RiderSessionState(
      isAuthenticated: true,
      approvalStatus: 'APPROVED',
      onlineStatus: 'ONLINE',
      profileReady: true,
      profileComplete: true,
    );
  }
}

class _QuietWallet extends WalletApi {
  _QuietWallet() : super(ApiClient(tokenStore: TokenStore()));

  @override
  Future<RiderWallet> wallet() async {
    return const RiderWallet(availableBalance: 0, walletAccountId: 'wallet');
  }

  @override
  Future<RiderCod> cod() async {
    return const RiderCod(codDue: 0, suspendThreshold: 100, suspended: false);
  }
}

class _QuietProfiles extends ProfilesApi {
  _QuietProfiles() : super(ApiClient(tokenStore: TokenStore()));

  @override
  Future<RiderApiProfile> rider() async {
    throw const ApiException(code: 'NOT_FOUND', message: 'missing');
  }
}

class _QuietNotices extends NotificationsApi {
  _QuietNotices() : super(ApiClient(tokenStore: TokenStore()));

  @override
  Future<List<ApiNotification>> list({int limit = 50}) async {
    return const <ApiNotification>[];
  }
}

class _ScriptedRiderApi extends RiderApi {
  _ScriptedRiderApi() : super(ApiClient(tokenStore: TokenStore()));

  int accepts = 0;
  final List<String> transitions = <String>[];
  String status = 'ASSIGNED';
  bool failAccept = false;
  bool failFirstHop = false;

  @override
  Future<List<RiderOffer>> listOffers() async {
    return <RiderOffer>[_offer()];
  }

  @override
  Future<ApiOrder> acceptOffer(String offerId) async {
    accepts += 1;
    if (failAccept) {
      throw const ApiException(
        code: 'OFFER_EXPIRED',
        message: 'This order offer expired.',
      );
    }
    status = 'ASSIGNED';
    return _apiOrder(status);
  }

  @override
  Future<ApiOrder> getOrder(String orderId) async {
    return _apiOrder(status);
  }

  @override
  Future<ApiOrder> transitionStatus({
    required String orderId,
    required String toStatus,
    String? reason,
  }) async {
    transitions.add(toStatus);
    if (failFirstHop && transitions.length == 1) {
      throw const ApiException(
        code: 'INVALID_TRANSITION',
        message: 'Transition ASSIGNED → EN_ROUTE_PICKUP is not allowed',
      );
    }
    status = toStatus;
    return _apiOrder(status);
  }

  @override
  Future<PickupWaitSnapshot> getPickupWait(String orderId) async {
    return PickupWaitSnapshot.fromJson(<String, Object?>{
      'timestamp_status': 'missing_arrival',
      'initial_waiting_minutes': 10,
      'waiting_charge_per_minute': '1.00',
      'elapsed_minutes': 0,
      'chargeable_minutes': 0,
      'amount': '0.00',
      'amount_source': 'preview',
      'vehicle_category_name': 'Bike',
    });
  }
}

RiderOffer _offer() {
  return RiderOffer(
    offerId: _offerId,
    orderId: _orderId,
    status: 'PENDING',
    createdAt: DateTime.utc(2026, 10, 14),
    displayId: 'IU-1',
    tripFare: 100,
    riderAmount: 85,
    distanceKm: 3,
    estimatedDurationSeconds: 600,
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    pickupAddress: 'Pickup lane',
    dropAddress: 'Drop lane',
  );
}

ApiOrder _apiOrder(String status) {
  return ApiOrder(
    orderId: _orderId,
    displayId: 'IU-1',
    canonicalStatus: status,
    createdAt: DateTime.utc(2026, 10, 14),
    tripFare: 100,
    riderAmount: 85,
  );
}
