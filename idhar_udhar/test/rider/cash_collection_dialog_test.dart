import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/rider/data/dummy/dummy_rider_repository.dart';
import 'package:idhar_udhar/rider/data/dummy/rider_finance.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/routing/rider_routes.dart';
import 'package:idhar_udhar/rider/screens/orders/active_delivery_screen.dart';
import 'package:idhar_udhar/rider/screens/orders/delivery_complete_screen.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';
import 'package:intl/intl.dart';

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

  testWidgets('cash due dialog shows the amount to collect', (tester) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()..payment = _cashPayment();
    final RiderOrder order = _mappedOrder();
    await _pump(
      tester,
      api: api,
      order: order,
    );

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();

    expect(find.text('Collect cash'), findsOneWidget);
    expect(find.text(_collectCopy(100)), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm Cash Collected'), findsOneWidget);
    expect(api.transitions, isEmpty);
    expect(api.paymentGets, 1);
    expect(order.customerCash, 0);
    expect(order.receiverCash, 0);
  });

  testWidgets('cancel sends no status request and does not complete', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()..payment = _cashPayment();
    final _QuietWalletApi wallet = _QuietWalletApi();
    final RiderOrder order = _mappedOrder();
    final ProviderContainer container = await _pump(
      tester,
      api: api,
      wallet: wallet,
      order: order,
    );

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Cash Collected'), findsNothing);
    expect(api.gets, 0);
    expect(api.transitions, isEmpty);
    expect(wallet.reads, 0);
    expect(wallet.settles, 0);
    expect(container.read(deliveryStatusProvider), DeliveryLifecycleStatus.goingToDrop);
    expect(container.read(riderWalletBalanceProvider), 0);
    expect(container.read(riderCodDueProvider), 0);
    expect(identical(container.read(activeOrderProvider), order), isTrue);
  });

  testWidgets('confirm cash collected uses remaining delivery hops', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..status = 'NEAR_DROP'
      ..payment = _cashPayment();
    final _QuietWalletApi wallet = _QuietWalletApi();
    final RiderOrder order = _mappedOrder();
    final ProviderContainer container = await _pump(
      tester,
      api: api,
      wallet: wallet,
      order: order,
    );

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Cash Collected'));
    await tester.pumpAndSettle();

    expect(api.transitions, <String>['DELIVERY_ATTEMPT', 'DELIVERED']);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.delivered,
    );
    expect(wallet.settles, 0);
    expect(identical(container.read(activeOrderProvider), order), isTrue);
    expect(order.customerCash, 0);
  });

  testWidgets('online payment with no cash due skips the dialog', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..status = 'NEAR_DROP'
      ..payment = _onlinePayment();
    final ProviderContainer container = await _pump(
      tester,
      api: api,
      wallet: _QuietWalletApi(),
      order: _mappedOrder(),
    );

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();

    expect(find.text('Collect cash'), findsNothing);
    expect(find.text('Confirm Cash Collected'), findsNothing);
    expect(api.transitions, <String>['DELIVERY_ATTEMPT', 'DELIVERED']);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.delivered,
    );
  });

  testWidgets('a second tap does not open another cash dialog', (tester) async {
    final Completer<void> hold = Completer<void>();
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..hold = hold
      ..payment = _cashPayment();
    await _pump(
      tester,
      api: api,
      wallet: _QuietWalletApi(),
      order: _mappedOrder(),
    );

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Cash Collected'));
    await tester.pump();

    expect(api.transitions, <String>['NEAR_DROP']);
    await tester.pumpAndSettle();
    expect(find.text('Confirm Cash Collected'), findsNothing);

    await tester.tap(find.text('Mark as delivered'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Confirm Cash Collected'), findsNothing);
    expect(api.gets, 1);
    expect(api.transitions, <String>['NEAR_DROP']);

    hold.complete();
    await tester.pumpAndSettle();
    expect(
      api.transitions,
      <String>['NEAR_DROP', 'DELIVERY_ATTEMPT', 'DELIVERED'],
    );
  });

  testWidgets('missing payment details do not complete the delivery', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..payment = ApiOrderPaymentView.tryParse(<String, Object?>{
        'order_id': _orderId,
        'display_id': 'IU-1',
        'fare': null,
        'responsibility': null,
        'plan': null,
        'payment_status': <String, Object?>{},
      });
    final _QuietWalletApi wallet = _QuietWalletApi();
    final ProviderContainer container = await _pump(
      tester,
      api: api,
      wallet: wallet,
      order: _mappedOrder(),
    );

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Cash Collected'), findsNothing);
    expect(
      find.text(
        'Payment details for this order are incomplete or inconsistent, so it was not marked delivered.',
      ),
      findsOneWidget,
    );
    expect(api.transitions, isEmpty);
    expect(wallet.reads, 0);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
  });

  testWidgets('inconsistent cash details do not complete the delivery', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..payment = _inconsistentPayment();
    final _QuietWalletApi wallet = _QuietWalletApi();
    final ProviderContainer container = await _pump(
      tester,
      api: api,
      wallet: wallet,
      order: _mappedOrder(),
    );

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Cash Collected'), findsNothing);
    expect(
      find.text(
        'Payment details for this order are incomplete or inconsistent, so it was not marked delivered.',
      ),
      findsOneWidget,
    );
    expect(api.transitions, isEmpty);
    expect(wallet.reads, 0);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
  });

  testWidgets('a failed payment request does not complete or get cached', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()..paymentThrows = true;
    final ProviderContainer container = await _pump(
      tester,
      api: api,
      order: _mappedOrder(),
    );

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();
    expect(api.paymentGets, 1);
    expect(api.transitions, isEmpty);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );

    ScaffoldMessenger.of(
      tester.element(find.byType(ActiveDeliveryScreen)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();

    expect(api.paymentGets, 2);
    expect(api.transitions, isEmpty);
  });

  testWidgets('payment for a different order does not complete delivery', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()
      ..payment = _cashPayment('22222222-2222-4222-8222-222222222222');
    final ProviderContainer container = await _pump(
      tester,
      api: api,
      order: _mappedOrder(),
    );

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Cash Collected'), findsNothing);
    expect(api.transitions, isEmpty);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
  });
}

String _collectCopy(num amount) {
  final String rupees = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  ).format(amount);
  return 'Collect $rupees. Confirm that this cash was physically collected.';
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _ScriptedRiderApi api,
  required RiderOrder order,
  _QuietWalletApi? wallet,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      riderApiProvider.overrideWithValue(api),
      if (wallet != null) walletApiProvider.overrideWithValue(wallet),
    ],
  );
  addTearDown(container.dispose);
  container.read(activeOrderProvider.notifier).state = order;
  container.read(deliveryStatusProvider.notifier).state =
      DeliveryLifecycleStatus.goingToDrop;

  final GoRouter router = GoRouter(
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

class _QuietWalletApi extends WalletApi {
  _QuietWalletApi() : super(ApiClient(tokenStore: TokenStore()));

  int reads = 0;
  int settles = 0;

  @override
  Future<RiderWallet> wallet() async {
    reads += 1;
    return const RiderWallet(availableBalance: 0, walletAccountId: 'wallet');
  }

  @override
  Future<RiderCod> cod() async {
    reads += 1;
    return const RiderCod(
      codDue: 0,
      suspendThreshold: 100,
      suspended: false,
    );
  }

  @override
  Future<void> settle(double amount) async {
    settles += 1;
  }
}

class _ScriptedRiderApi extends RiderApi {
  _ScriptedRiderApi() : super(ApiClient(tokenStore: TokenStore()));

  final List<String> transitions = <String>[];
  int gets = 0;
  int paymentGets = 0;
  String status = 'IN_TRANSIT';
  Completer<void>? hold;
  ApiOrderPaymentView? payment;
  bool paymentThrows = false;

  @override
  Future<ApiOrder> getOrder(String orderId) async {
    gets += 1;
    return _apiOrder(status);
  }

  @override
  Future<ApiOrderPaymentView?> getOrderPayment(String orderId) async {
    paymentGets += 1;
    if (paymentThrows) {
      throw const ApiException(
        code: 'UNAVAILABLE',
        message: 'Payment could not be loaded',
      );
    }
    return payment;
  }

  @override
  Future<ApiOrder> transitionStatus({
    required String orderId,
    required String toStatus,
    String? reason,
  }) async {
    transitions.add(toStatus);
    final Completer<void>? gate = hold;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
      hold = null;
    }
    status = toStatus;
    return _apiOrder(status);
  }
}

const String _orderId = '11111111-1111-4111-8111-111111111111';

RiderOrder _mappedOrder() {
  return OrderMapper.toRiderOrder(
    offer: RiderOffer(
      offerId: '22222222-2222-4222-8222-222222222222',
      orderId: _orderId,
      status: 'ACCEPTED',
      createdAt: DateTime.utc(2026, 10, 11),
      displayId: 'IU-1',
      tripFare: 100,
      riderAmount: 40,
      distanceKm: 3,
      estimatedDurationSeconds: 12 * 60,
      pickupAddress: 'Pickup lane',
      dropAddress: 'Drop lane',
    ),
  );
}

ApiOrderPaymentView _cashPayment([String orderId = _orderId]) {
  return ApiOrderPaymentView.tryParse(
    _paymentBody(
      orderId: orderId,
      customerResponsibility: '60.00',
      receiverResponsibility: '40.00',
      customerOnline: '0.00',
      customerCash: '60.00',
      receiverOnline: '0.00',
      receiverCash: '40.00',
      bill: '100.00',
    ),
  )!;
}

ApiOrderPaymentView _onlinePayment() {
  return ApiOrderPaymentView.tryParse(
    _paymentBody(
      orderId: _orderId,
      customerResponsibility: '100.00',
      receiverResponsibility: '0.00',
      customerOnline: '100.00',
      customerCash: '0.00',
      receiverOnline: '0.00',
      receiverCash: '0.00',
      bill: '100.00',
    ),
  )!;
}

ApiOrderPaymentView _inconsistentPayment() {
  return ApiOrderPaymentView.tryParse(
    _paymentBody(
      orderId: _orderId,
      customerResponsibility: '100.00',
      receiverResponsibility: '0.00',
      customerOnline: '0.00',
      customerCash: '0.00',
      receiverOnline: '0.00',
      receiverCash: '0.00',
      bill: '100.00',
    ),
  )!;
}

Map<String, Object?> _paymentBody({
  required String orderId,
  required String customerResponsibility,
  required String receiverResponsibility,
  required String customerOnline,
  required String customerCash,
  required String receiverOnline,
  required String receiverCash,
  required String bill,
}) {
  return <String, Object?>{
    'order_id': orderId,
    'display_id': 'IU-1',
    'fare': <String, Object?>{
      'trip_fare': bill,
      'net_payable': bill,
      'discount': '0.00',
      'tax': '0.00',
    },
    'responsibility': <String, Object?>{
      'payment_responsibility_id': '33333333-3333-4333-8333-333333333333',
      'order_id': orderId,
      'applicable_bill_total': bill,
      'customer_responsibility': customerResponsibility,
      'receiver_responsibility': receiverResponsibility,
      'who_pays': 'SPLIT',
      'created_at': '2026-10-11T00:00:00.000Z',
    },
    'plan': <String, Object?>{
      'payment_plan_id': '44444444-4444-4444-8444-444444444444',
      'order_id': orderId,
      'customer_planned_online': customerOnline,
      'customer_planned_cash': customerCash,
      'receiver_planned_online': receiverOnline,
      'receiver_planned_cash': receiverCash,
      'created_at': '2026-10-11T00:00:00.000Z',
    },
    'payment_status': <String, Object?>{
      'customer': <String, Object?>{
        'owed': customerResponsibility,
        'paid': '0.00',
        'status': 'UNPAID',
      },
      'receiver': <String, Object?>{
        'owed': receiverResponsibility,
        'paid': '0.00',
        'status': 'UNPAID',
      },
      'overall': <String, Object?>{
        'owed': bill,
        'paid': '0.00',
        'status': 'UNPAID',
      },
    },
  };
}

ApiOrder _apiOrder(String status) {
  return ApiOrder(
    orderId: '11111111-1111-4111-8111-111111111111',
    displayId: 'IU-1',
    canonicalStatus: status,
    createdAt: DateTime.utc(2026, 10, 11),
  );
}
