import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/data/dummy/dummy_rider_repository.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/screens/orders/active_delivery_screen.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';

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

  Future<ProviderContainer> pumpDelivery(
    WidgetTester tester, {
    required _ScriptedRiderApi api,
    required DeliveryLifecycleStatus status,
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

  Future<void> openReceiverUnavailableAction(WidgetTester tester) async {
    await tester.tap(find.textContaining('View Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receiver Unavailable'));
    await tester.pumpAndSettle();
  }

  testWidgets('pickup steps do not show Receiver Unavailable', (tester) async {
    for (final DeliveryLifecycleStatus status in <DeliveryLifecycleStatus>[
      DeliveryLifecycleStatus.accepted,
      DeliveryLifecycleStatus.goingToPickup,
      DeliveryLifecycleStatus.arrivedAtPickup,
      DeliveryLifecycleStatus.packagePickedUp,
    ]) {
      final _ScriptedRiderApi api = _ScriptedRiderApi();
      await pumpDelivery(tester, api: api, status: status);
      expect(find.text('Receiver Unavailable'), findsNothing);
      expect(find.text('Receiver not available?'), findsNothing);
      expect(find.textContaining('View Details'), findsNothing);
      expect(api.transitions, isEmpty);
    }
  });

  testWidgets('the action opens a confirmation dialog', (tester) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    await pumpDelivery(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToDrop,
    );
    await openReceiverUnavailableAction(tester);
    expect(
      find.text(
        'Confirming this records a failed delivery attempt because the receiver is unavailable.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(api.transitions, isEmpty);
  });

  testWidgets('cancel sends no status request and leaves delivery status', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi();
    final ProviderContainer container = await pumpDelivery(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToDrop,
    );
    await openReceiverUnavailableAction(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm'), findsNothing);
    expect(api.gets, 0);
    expect(api.transitions, isEmpty);
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.goingToDrop,
    );
  });

  testWidgets('confirm uses remaining server hops and does not replay them', (
    tester,
  ) async {
    final _ScriptedRiderApi api = _ScriptedRiderApi()..status = 'NEAR_DROP';
    final ProviderContainer container = await pumpDelivery(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToDrop,
    );
    await openReceiverUnavailableAction(tester);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(
      api.transitions,
      <String>['DELIVERY_ATTEMPT', 'RECEIVER_UNAVAILABLE'],
    );
    expect(
      container.read(deliveryStatusProvider),
      DeliveryLifecycleStatus.receiverUnavailable,
    );
  });

  testWidgets('a second tap does not start another sequence', (tester) async {
    final Completer<void> hold = Completer<void>();
    final _ScriptedRiderApi api = _ScriptedRiderApi()..hold = hold;
    await pumpDelivery(
      tester,
      api: api,
      status: DeliveryLifecycleStatus.goingToDrop,
    );
    await openReceiverUnavailableAction(tester);
    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(api.transitions, <String>['NEAR_DROP']);
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsNothing);

    await openReceiverUnavailableAction(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Confirm'), findsNothing);
    expect(api.gets, 1);
    expect(api.transitions, <String>['NEAR_DROP']);

    hold.complete();
    await tester.pumpAndSettle();
    expect(
      api.transitions,
      <String>['NEAR_DROP', 'DELIVERY_ATTEMPT', 'RECEIVER_UNAVAILABLE'],
    );
  });
}

class _ScriptedRiderApi extends RiderApi {
  _ScriptedRiderApi() : super(ApiClient(tokenStore: TokenStore()));

  final List<String> transitions = <String>[];
  int gets = 0;
  String status = 'IN_TRANSIT';
  Completer<void>? hold;

  @override
  Future<PickupWaitSnapshot> getPickupWait(String orderId) async {
    return PickupWaitSnapshot(
      arrivalAt: DateTime.utc(2026, 10, 14, 8),
      pickedUpAt: null,
      serverNow: DateTime.utc(2026, 10, 14, 8, 1, 20),
      timestampStatus: 'ok',
      initialWaitingMinutes: 10,
      perMinute: '2.00',
      elapsedSeconds: 80,
      elapsedMinutes: 1,
      chargeableMinutes: 0,
      amount: '0.00',
      amountSource: 'preview',
      vehicleCategoryName: 'Scooty',
    );
  }

  @override
  Future<ApiOrder> getOrder(String orderId) async {
    gets += 1;
    return _apiOrder(status);
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

RiderOrder _order() {
  return const RiderOrder(
    id: 'IU-1',
    backendOrderId: '11111111-1111-4111-8111-111111111111',
    pickup: 'Pickup lane',
    drop: 'Drop lane',
    distanceKm: 3,
    estimatedEarnings: 40,
    estimatedMinutes: 12,
    customerMaskedName: 'A.',
    customerMaskedPhone: '98XXXXXX10',
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
