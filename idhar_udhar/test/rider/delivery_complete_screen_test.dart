import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/rider/data/dummy/dummy_rider_repository.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/routing/rider_routes.dart';
import 'package:idhar_udhar/rider/screens/orders/active_delivery_screen.dart';
import 'package:idhar_udhar/rider/screens/orders/delivery_complete_screen.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';

const String _orderId = '11111111-1111-4111-8111-111111111111';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
  });

  testWidgets('confirmed DELIVERED opens the completion screen once', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..status = 'NEAR_DROP'
      ..payment = _onlinePayment();
    await _pumpDelivery(tester, api: api, order: _mappedOrder(riderAmount: 85));

    await tester.tap(find.text('ARRIVED AT DROP LOCATION'));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Delivery complete'), findsOneWidget);
    expect(find.text('Congratulations. This order has been delivered.'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(api.transitions, <String>['DELIVERY_ATTEMPT', 'DELIVERED']);
  });

  testWidgets('a failed status request stays on the delivery screen', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..status = 'NEAR_DROP'
      ..payment = _onlinePayment()
      ..failTransition = true;
    await _pumpDelivery(tester, api: api, order: _mappedOrder());

    await tester.tap(find.text('ARRIVED AT DROP LOCATION'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery complete'), findsNothing);
    expect(find.text('Mark as delivered'), findsOneWidget);
    expect(
      find.text(
        'The server rejected this status change. The order is currently NEAR_DROP. Try the step that matches it.',
      ),
      findsOneWidget,
    );
    expect(api.transitions, <String>['DELIVERY_ATTEMPT']);
  });

  testWidgets('a non-DELIVERED status does not open completion', (tester) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..status = 'NEAR_DROP'
      ..payment = _onlinePayment()
      ..returnedStatus = 'IN_TRANSIT';
    await _pumpDelivery(tester, api: api, order: _mappedOrder());

    await tester.tap(find.text('ARRIVED AT DROP LOCATION'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery complete'), findsNothing);
    expect(find.text('Mark as delivered'), findsOneWidget);
    expect(api.transitions, <String>['DELIVERY_ATTEMPT', 'DELIVERED']);
  });

  testWidgets('a missing payment view does not open completion', (tester) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()..payment = _nullPayment();
    await _pumpDelivery(tester, api: api, order: _mappedOrder());
    await tester.tap(find.text('ARRIVED AT DROP LOCATION'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery complete'), findsNothing);
    expect(find.text('Mark as delivered'), findsOneWidget);
    expect(
      find.text(
        'Payment details for this order are incomplete or inconsistent, so it was not marked delivered.',
      ),
      findsOneWidget,
    );
    expect(api.transitions, <String>['NEAR_DROP']);
  });

  testWidgets('cancelling cash collection does not open completion', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()..payment = _cashPayment();
    await _pumpDelivery(tester, api: api, order: _mappedOrder());
    await tester.tap(find.text('ARRIVED AT DROP LOCATION'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery complete'), findsNothing);
    expect(find.text('Confirm Cash Collected'), findsNothing);
    expect(find.text('Mark as delivered'), findsOneWidget);
    expect(api.transitions, <String>['NEAR_DROP']);
  });

  testWidgets('completion screen omits a missing CRN and earning', (tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(activeOrderProvider.notifier).state = _mappedOrder();

    final GoRouter router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(RiderRoutes.deliveryComplete);
    await tester.pumpAndSettle();

    expect(find.text('Delivery complete'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('CRN'), findsNothing);
    expect(find.text('Earning'), findsNothing);
    expect(find.text('Back to Dashboard'), findsOneWidget);

    await tester.tap(find.text('Back to Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Rider dashboard'), findsOneWidget);
    expect(container.read(activeOrderProvider), isNull);
  });

  testWidgets('completion screen shows CRN and rider earning when present', (
    tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(activeOrderProvider.notifier).state = _mappedOrder(
      crn: 'IU-CRN-GJ-1234567890',
      riderAmount: 85,
    );
    final GoRouter router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(RiderRoutes.deliveryComplete);
    await tester.pumpAndSettle();

    expect(find.text('IU-CRN-GJ-1234567890'), findsOneWidget);
    expect(find.text('Earning'), findsOneWidget);
    expect(find.textContaining('85'), findsOneWidget);
  });
}

Future<void> _pumpDelivery(
  WidgetTester tester, {
  required _ScriptedRiderApi api,
  required RiderOrder order,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      riderApiProvider.overrideWithValue(api),
      walletApiProvider.overrideWithValue(_QuietWalletApi()),
    ],
  );
  addTearDown(container.dispose);
  container.read(activeOrderProvider.notifier).state = order;
  container.read(deliveryStatusProvider.notifier).state =
      DeliveryLifecycleStatus.goingToDrop;

  final GoRouter router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

GoRouter _router() {
  return GoRouter(
    initialLocation: RiderRoutes.activeDelivery,
    routes: <RouteBase>[
      GoRoute(
        path: RiderRoutes.activeDelivery,
        builder: (BuildContext context, GoRouterState state) {
          return const ActiveDeliveryScreen();
        },
      ),
      GoRoute(
        path: RiderRoutes.deliveryComplete,
        builder: (BuildContext context, GoRouterState state) {
          return const DeliveryCompleteScreen();
        },
      ),
      GoRoute(
        path: RiderRoutes.dashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Rider dashboard'));
        },
      ),
    ],
  );
}

class _QuietWalletApi extends WalletApi {
  _QuietWalletApi() : super(ApiClient(tokenStore: TokenStore()));

  @override
  Future<RiderWallet> wallet() async {
    return const RiderWallet(availableBalance: 0, walletAccountId: 'wallet');
  }

  @override
  Future<RiderCod> cod() async {
    return const RiderCod(codDue: 0, suspendThreshold: 100, suspended: false);
  }
}

class _ScriptedRiderApi extends RiderApi {
  _ScriptedRiderApi() : super(ApiClient(tokenStore: TokenStore()));

  final List<String> transitions = <String>[];
  String status = 'IN_TRANSIT';
  String? returnedStatus;
  bool failTransition = false;
  ApiOrderPaymentView? payment;

  @override
  Future<ApiOrder> getOrder(String orderId) async {
    return _apiOrder(status);
  }

  @override
  Future<ApiOrderPaymentView?> getOrderPayment(String orderId) async {
    return payment;
  }

  @override
  Future<ApiOrder> transitionStatus({
    required String orderId,
    required String toStatus,
    String? reason,
  }) async {
    transitions.add(toStatus);
    if (failTransition) {
      throw const ApiException(
        code: 'INVALID_TRANSITION',
        message: 'That order update is not allowed yet.',
      );
    }
    status = returnedStatus ?? toStatus;
    return _apiOrder(status);
  }
}

RiderOrder _mappedOrder({String? crn, double? riderAmount}) {
  return OrderMapper.toRiderOrder(
    offer: RiderOffer(
      offerId: '22222222-2222-4222-8222-222222222222',
      orderId: _orderId,
      status: 'ACCEPTED',
      createdAt: DateTime.utc(2026, 10, 11),
      displayId: 'IU-1',
      crn: crn,
      tripFare: 100,
      riderAmount: riderAmount,
      pickupAddress: 'Pickup lane',
      dropAddress: 'Drop lane',
    ),
  );
}

ApiOrderPaymentView _onlinePayment() {
  return ApiOrderPaymentView.tryParse(_paymentBody(
    customerResponsibility: '100.00',
    receiverResponsibility: '0.00',
    customerOnline: '100.00',
    customerCash: '0.00',
    receiverOnline: '0.00',
    receiverCash: '0.00',
  ))!;
}

ApiOrderPaymentView _cashPayment() {
  return ApiOrderPaymentView.tryParse(_paymentBody(
    customerResponsibility: '100.00',
    receiverResponsibility: '0.00',
    customerOnline: '0.00',
    customerCash: '100.00',
    receiverOnline: '0.00',
    receiverCash: '0.00',
  ))!;
}

ApiOrderPaymentView _nullPayment() {
  return ApiOrderPaymentView.tryParse(<String, Object?>{
    'order_id': _orderId,
    'responsibility': null,
    'plan': null,
  })!;
}

Map<String, Object?> _paymentBody({
  required String customerResponsibility,
  required String receiverResponsibility,
  required String customerOnline,
  required String customerCash,
  required String receiverOnline,
  required String receiverCash,
}) {
  return <String, Object?>{
    'order_id': _orderId,
    'responsibility': <String, Object?>{
      'order_id': _orderId,
      'applicable_bill_total': '100.00',
      'customer_responsibility': customerResponsibility,
      'receiver_responsibility': receiverResponsibility,
    },
    'plan': <String, Object?>{
      'order_id': _orderId,
      'customer_planned_online': customerOnline,
      'customer_planned_cash': customerCash,
      'receiver_planned_online': receiverOnline,
      'receiver_planned_cash': receiverCash,
    },
  };
}

ApiOrder _apiOrder(String status) {
  return ApiOrder(
    orderId: _orderId,
    displayId: 'IU-1',
    canonicalStatus: status,
    createdAt: DateTime.utc(2026, 10, 11),
  );
}
