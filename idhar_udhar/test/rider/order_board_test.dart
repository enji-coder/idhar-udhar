import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/rider/data/dummy/dummy_rider_repository.dart';
import 'package:idhar_udhar/rider/data/local/rider_prefs.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/features/orders/external_navigation.dart';
import 'package:idhar_udhar/rider/features/orders/rider_order_board.dart';
import 'package:idhar_udhar/rider/features/orders/rider_order_board_providers.dart';
import 'package:idhar_udhar/rider/routing/rider_routes.dart';
import 'package:idhar_udhar/rider/screens/dashboard/rider_active_delivery_section.dart';
import 'package:idhar_udhar/rider/screens/orders/rider_history_screen.dart';
import 'package:idhar_udhar/rider/screens/orders/rider_ledger_screen.dart';
import 'package:idhar_udhar/rider/screens/orders/rider_past_order_screen.dart';
import 'package:idhar_udhar/rider/screens/wallet/rider_wallet_screen.dart';
import 'package:idhar_udhar/rider/state/rider_session.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(RiderNavSession.clear);

  test('ledger rows stay financial and drop incomplete entries', () {
    final List<RiderWalletLedgerEntry> entries = parseWalletLedger(
      <Map<String, Object?>>[
        <String, Object?>{
          'wallet_ledger_id': 'older',
          'direction': 'DEBIT',
          'amount': '40.00',
          'entry_type': 'PAYOUT',
          'created_at': '2026-10-01T10:00:00Z',
        },
        <String, Object?>{
          'wallet_ledger_id': 'newer',
          'direction': 'credit',
          'amount': '85.50',
          'entry_type': 'EARNING',
          'related_order_id': '11111111-1111-4111-8111-111111111111',
          'created_at': '2026-10-02T10:00:00Z',
        },
        <String, Object?>{
          'wallet_ledger_id': '',
          'direction': 'CREDIT',
          'amount': '1',
        },
      ],
    );

    expect(entries, hasLength(2));
    expect(entries.first.id, 'newer');
    expect(entries.first.isCredit, isTrue);
    expect(entries.first.amount, 85.50);
    expect(ledgerEntryTitle(entries.first.entryType), 'Earning');
    expect(
      entries.first.relatedOrderId,
      '11111111-1111-4111-8111-111111111111',
    );
    expect(entries.last.entryType, 'PAYOUT');
    expect(
      entries.any((RiderWalletLedgerEntry entry) => entry.amount == 1),
      isFalse,
    );
  });

  test('ledger keeps payment references and does not invent a status', () {
    final RiderWalletLedgerEntry? entry = tryParseWalletLedgerEntry(
      <String, Object?>{
        'wallet_ledger_id': 'ledger-9',
        'direction': 'CREDIT',
        'amount': '120.00',
        'entry_type': 'RECHARGE',
        'related_payment_transaction_id': 'pay-9',
        'created_at': '2026-10-02T15:30:00+05:30',
      },
    );
    expect(entry, isNotNull);
    expect(entry!.relatedPaymentTransactionId, 'pay-9');
    expect(entry.createdAt!.toUtc(), DateTime.utc(2026, 10, 2, 10, 0));
    expect(entry.isCredit, isTrue);
    expect(ledgerEntryTitle('COD_SETTLEMENT'), 'COD settlement');
    expect(
      tryParseWalletLedgerEntry(<String, Object?>{
        'wallet_ledger_id': 'bad',
        'direction': 'DEBIT',
        'entry_type': 'PAYOUT',
      }),
      isNull,
    );
  });

  test('trip history lists cancelled orders and keeps earnings optional',
      () async {
    final DateTime frozen = DateTime.utc(2026, 10, 12, 11, 2);
    const String deliveredId = '11111111-1111-4111-8111-111111111111';
    const String cancelledId = '22222222-2222-4222-8222-222222222222';
    final RiderHistorySnapshot snapshot = await loadRiderOrderHistory(
      orders: (String? cursor) async => RiderHistoryPage(
        orders: <RiderHistoryOrder>[
          RiderHistoryOrder(
            orderId: cancelledId,
            displayId: 'IU-CANCEL',
            canonicalStatus: 'CANCELLED',
            createdAt: DateTime.utc(2026, 10, 11),
            pickupAddress: 'Cancel pickup',
            dropAddress: 'Cancel drop',
          ),
          RiderHistoryOrder(
            orderId: deliveredId,
            displayId: 'IU-1',
            canonicalStatus: 'DELIVERED',
            createdAt: DateTime.utc(2026, 10, 1, 4),
            pickupAddress: 'Pickup lane',
            dropAddress: 'Drop lane',
          ),
        ],
      ),
      earnings: () async => <RiderEarningRow>[
        RiderEarningRow(
          orderId: deliveredId,
          displayId: 'IU-1',
          tripFare: 120,
          riderAmount: 90,
          frozenAt: frozen,
        ),
      ],
      order: (String orderId) async => ApiOrder(
        orderId: orderId,
        displayId: orderId == cancelledId ? 'IU-CANCEL' : 'IU-1',
        canonicalStatus: orderId == cancelledId ? 'CANCELLED' : 'DELIVERED',
        createdAt: DateTime.utc(2026, 10, 1, 4),
        pickupAddress: 'Pickup lane',
        dropAddress: 'Drop lane',
      ),
      limit: 20,
    );
    expect(snapshot.records, hasLength(2));
    expect(snapshot.records.first.canonicalStatus, 'CANCELLED');
    expect(snapshot.records.first.tripFare, isNull);
    expect(snapshot.records.first.pickup, 'Pickup lane');
    final RiderHistoryRecord delivered = snapshot.records.last;
    expect(delivered.when, frozen);
    expect(delivered.tripFare, 120);
    expect(delivered.riderAmount, 90);
    expect(delivered.canonicalStatus, 'DELIVERED');

    final RiderHistorySnapshot undated = await loadRiderOrderHistory(
      orders: (String? cursor) async => const RiderHistoryPage(
        orders: <RiderHistoryOrder>[
          RiderHistoryOrder(
            orderId: '33333333-3333-4333-8333-333333333333',
            displayId: 'IU-2',
            canonicalStatus: 'CANCELLED',
            pickupAddress: 'Saved pickup',
          ),
        ],
      ),
      earnings: () async => const <RiderEarningRow>[],
      order: (String orderId) async =>
          throw const ApiException(code: 'OFF', message: 'Offline'),
      limit: 20,
    );
    expect(undated.records.single.when, isNull);
    expect(undated.records.single.canonicalStatus, 'CANCELLED');
    expect(undated.records.single.pickup, 'Saved pickup');
    expect(undated.records.single.detailsLoaded, isFalse);
    expect(undated.failedDetails, 1);

    expect(
      () => loadRiderOrderHistory(
        orders: (String? cursor) async =>
            throw const ApiException(code: 'OFF', message: 'Offline'),
        earnings: () async => const <RiderEarningRow>[],
        order: (String orderId) async => _api(orderId, 'DELIVERED', 'IU'),
        limit: 20,
      ),
      throwsA(isA<ApiException>()),
    );

    final RiderHistorySnapshot withoutFinance = await loadRiderOrderHistory(
      orders: (String? cursor) async => const RiderHistoryPage(
        orders: <RiderHistoryOrder>[
          RiderHistoryOrder(
            orderId: '44444444-4444-4444-8444-444444444444',
            displayId: 'IU-3',
            canonicalStatus: 'DELIVERED',
            createdAt: null,
          ),
        ],
      ),
      earnings: () async =>
          throw const ApiException(code: 'OFF', message: 'Offline'),
      order: (String orderId) async => _api(orderId, 'DELIVERED', 'IU-3'),
      limit: 20,
    );
    expect(withoutFinance.records.single.displayId, 'IU-3');
    expect(withoutFinance.records.single.tripFare, isNull);
    expect(withoutFinance.records.single.riderAmount, isNull);
  });

  test('trip history pages follow the cursor without repeating rows', () async {
    const String first = '11111111-1111-4111-8111-111111111111';
    const String second = '22222222-2222-4222-8222-222222222222';
    final List<String?> cursors = <String?>[];
    final RiderHistorySnapshot snapshot = await loadRiderOrderHistory(
      orders: (String? cursor) async {
        cursors.add(cursor);
        if (cursor == null) {
          return const RiderHistoryPage(
            orders: <RiderHistoryOrder>[
              RiderHistoryOrder(
                orderId: first,
                displayId: 'IU-1',
                canonicalStatus: 'CANCELLED',
              ),
            ],
            nextCursor: 'page-2',
          );
        }
        return const RiderHistoryPage(
          orders: <RiderHistoryOrder>[
            RiderHistoryOrder(
              orderId: second,
              displayId: 'IU-2',
              canonicalStatus: 'DELIVERED',
            ),
          ],
        );
      },
      earnings: () async => const <RiderEarningRow>[],
      order: (String orderId) async => _api(orderId, 'CANCELLED', orderId),
      limit: 20,
    );
    expect(cursors, <String?>[null, 'page-2']);
    expect(
      snapshot.records.map((RiderHistoryRecord row) => row.orderId).toList(),
      <String>[first, second],
    );
    expect(snapshot.hasMore, isFalse);
  });

  test('history filters use server status and skip unknown details', () {
    final RiderHistoryRecord delivered = _record('DELIVERED');
    final RiderHistoryRecord cancelled = _record('CANCELLED');
    final RiderHistoryRecord running = _record('IN_TRANSIT');
    final RiderHistoryRecord unknown = RiderHistoryRecord(
      orderId: 'missing',
      displayId: 'IU-9',
      when: DateTime.utc(2026, 10, 3),
      detailsLoaded: false,
    );

    expect(
      historyRecordMatches(delivered, RiderHistoryFilter.completed),
      isTrue,
    );
    expect(
      historyRecordMatches(cancelled, RiderHistoryFilter.cancelled),
      isTrue,
    );
    expect(historyRecordMatches(running, RiderHistoryFilter.running), isTrue);
    expect(historyRecordMatches(unknown, RiderHistoryFilter.all), isTrue);
    expect(
      historyRecordMatches(unknown, RiderHistoryFilter.completed),
      isFalse,
    );
    expect(historyStatusLabel('CANCELLED'), 'Cancelled');
    expect(historyStatusLabel('IN_TRANSIT'), 'Going to Drop');
    expect(historyStatusLabel('RESEND_REQUESTED'), 'Resend requested');
    expect(historyStatusLabel('RESEND_IN_PROGRESS'), 'Resend in progress');
    expect(historyStatusLabel('RESEND_COMPLETED'), 'Resend completed');
    expect(riderCanonicalIsRunning('DELIVERED'), isFalse);
    expect(riderCanonicalIsRunning('RESEND_REQUESTED'), isTrue);
    expect(riderCanonicalIsRunning('RESEND_IN_PROGRESS'), isTrue);
    expect(riderCanonicalIsRunning('PARCEL_AT_COMPANY_OFFICE'), isTrue);
    expect(riderCanonicalIsFinished('PARCEL_AT_COMPANY_OFFICE'), isFalse);
    expect(riderCanonicalIsFinished('RESEND_COMPLETED'), isTrue);
    expect(
      historyRecordMatches(
        _record('RESEND_REQUESTED'),
        RiderHistoryFilter.completed,
      ),
      isFalse,
    );
    expect(
      historyRecordMatches(
        _record('RESEND_REQUESTED'),
        RiderHistoryFilter.running,
      ),
      isTrue,
    );
    expect(
      localDeliveryStillRunning(DeliveryLifecycleStatus.parcelAtCompanyOffice),
      isTrue,
    );
    expect(paymentMethodLabel(cash: 85, online: 0), 'Cash');
    expect(paymentMethodLabel(cash: 0, online: 120), 'Online');
    expect(paymentMethodLabel(cash: 40, online: 80), 'Cash + Online');
    expect(paymentMethodLabel(cash: 0, online: 0), isNull);
  });

  test('remembered live order is restored and a finished one is not', () async {
    const String id = '11111111-1111-4111-8111-111111111111';
    final RiderRunningBoard live = await loadRunningDeliveries(
      local: null,
      localStatus: DeliveryLifecycleStatus.accepted,
      rememberedOrderId: id,
      earnings: () async => const <RiderEarningRow>[],
      order: (String orderId) async => _api(orderId, 'IN_TRANSIT', 'IU-1'),
    );
    expect(live.running, hasLength(1));
    expect(live.running.first.canonicalStatus, 'IN_TRANSIT');
    expect(live.clearRemembered, isFalse);
    final RunningDeliveryOpenPlan plan = planRunningDeliveryOpen(
      tappedOrderId: id,
      localOrderId: null,
      localStillRunning: false,
      hasRiderPhase: riderCanonicalHasDeliveryPhase('IN_TRANSIT'),
    );
    expect(plan.route, RiderRoutes.activeDelivery);
    expect(plan.adopt, isTrue);
    expect(plan.readOnly, isFalse);

    final RiderRunningBoard done = await loadRunningDeliveries(
      local: null,
      localStatus: DeliveryLifecycleStatus.accepted,
      rememberedOrderId: id,
      earnings: () async => const <RiderEarningRow>[],
      order: (String orderId) async => _api(orderId, 'DELIVERED', 'IU-1'),
    );
    expect(done.running, isEmpty);
    expect(done.clearRemembered, isTrue);

    final RiderRunningBoard cancelled = await loadRunningDeliveries(
      local: null,
      localStatus: DeliveryLifecycleStatus.accepted,
      extraOrderIds: const <String>[id],
      earnings: () async => const <RiderEarningRow>[],
      order: (String orderId) async => _api(orderId, 'CANCELLED', 'IU-1'),
    );
    expect(cancelled.running, isEmpty);
  });

  test('saved order id survives provider recreation and logout clears it',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await rememberLiveOrderId('order-9');
    expect(await readRememberedLiveOrderId(), 'order-9');
    await RiderPrefs.clearLoggedIn();
    expect(await readRememberedLiveOrderId(), isNull);
  });

  test('running deliveries keep every active order and clear a finished one',
      () async {
    final RiderRunningBoard board = await loadRunningDeliveries(
      local: _local('11111111-1111-4111-8111-111111111111'),
      localStatus: DeliveryLifecycleStatus.goingToDrop,
      earnings: () async => <RiderEarningRow>[
        _earning('11111111-1111-4111-8111-111111111111', 'IU-1'),
        _earning('22222222-2222-4222-8222-222222222222', 'IU-2'),
        _earning('33333333-3333-4333-8333-333333333333', 'IU-3'),
      ],
      order: (String orderId) async {
        if (orderId.startsWith('1111')) {
          return _api(orderId, 'DELIVERED', 'IU-1');
        }
        if (orderId.startsWith('2222')) {
          return _api(orderId, 'IN_TRANSIT', 'IU-2');
        }
        return _api(orderId, 'ARRIVED_PICKUP', 'IU-3');
      },
    );

    expect(board.clearLocalOrder, isTrue);
    expect(board.running, hasLength(2));
    expect(
      board.running.map((RiderTrackedDelivery item) => item.order.id).toList(),
      <String>['IU-3', 'IU-2'],
    );
  });

  test('resend and office handover stay visible and are not completed',
      () async {
    final RiderRunningBoard board = await loadRunningDeliveries(
      local: _local('11111111-1111-4111-8111-111111111111'),
      localStatus: DeliveryLifecycleStatus.parcelAtCompanyOffice,
      earnings: () async => <RiderEarningRow>[
        _earning('22222222-2222-4222-8222-222222222222', 'IU-2'),
      ],
      order: (String orderId) async {
        if (orderId.startsWith('1111')) {
          return _api(orderId, 'RESEND_REQUESTED', 'IU-1');
        }
        return _api(orderId, 'RESEND_IN_PROGRESS', 'IU-2');
      },
    );

    expect(board.clearLocalOrder, isFalse);
    expect(board.running, hasLength(2));
    expect(
      board.running.map((RiderTrackedDelivery item) => item.canonicalStatus),
      <String>['RESEND_REQUESTED', 'RESEND_IN_PROGRESS'],
    );
  });

  test('opening a different running order does not replace the current trip',
      () {
    final RunningDeliveryOpenPlan same = planRunningDeliveryOpen(
      tappedOrderId: 'order-a',
      localOrderId: 'order-a',
      localStillRunning: true,
      hasRiderPhase: true,
    );
    final RunningDeliveryOpenPlan other = planRunningDeliveryOpen(
      tappedOrderId: 'order-b',
      localOrderId: 'order-a',
      localStillRunning: true,
      hasRiderPhase: true,
    );
    final RunningDeliveryOpenPlan fresh = planRunningDeliveryOpen(
      tappedOrderId: 'order-b',
      localOrderId: null,
      localStillRunning: false,
      hasRiderPhase: true,
    );
    final RunningDeliveryOpenPlan resend = planRunningDeliveryOpen(
      tappedOrderId: 'order-c',
      localOrderId: null,
      localStillRunning: false,
      hasRiderPhase: false,
    );

    expect(same.adopt, isFalse);
    expect(same.readOnly, isFalse);
    expect(same.route, RiderRoutes.activeDelivery);
    expect(other.readOnly, isTrue);
    expect(other.route, '${RiderRoutes.pastOrder}?id=order-b');
    expect(fresh.adopt, isTrue);
    expect(fresh.route, RiderRoutes.activeDelivery);
    expect(resend.readOnly, isTrue);
    expect(resend.adopt, isFalse);
    expect(resend.route, '${RiderRoutes.pastOrder}?id=order-c');
  });

  testWidgets('orders tab shows trip history without a ledger button',
      (tester) async {
    final GoRouter router = _router(
      const RiderHistoryScreen(showAppBar: false),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          riderOrderHistoryProvider.overrideWith(
            (Ref ref) async => const RiderHistorySnapshot(
              records: <RiderHistoryRecord>[],
              total: 0,
              failedDetails: 0,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trip History'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('History'), findsNothing);
    expect(find.text('Ledger'), findsNothing);
  });

  testWidgets('order history shows real rows, empty, and error states',
      (tester) async {
    final RiderHistorySnapshot snapshot = RiderHistorySnapshot(
      records: <RiderHistoryRecord>[
        RiderHistoryRecord(
          orderId: '11111111-1111-4111-8111-111111111111',
          displayId: 'IU-1',
          crn: 'CRN1',
          pickup: 'Pickup lane',
          drop: 'Drop lane',
          canonicalStatus: 'DELIVERED',
          when: DateTime.utc(2026, 10, 2, 9),
          tripFare: 120,
          riderAmount: 90,
          detailsLoaded: true,
        ),
      ],
      total: 1,
      failedDetails: 0,
    );
    await tester.pumpWidget(
      _scoped(
        const RiderHistoryScreen(),
        overrides: <Override>[
          riderOrderHistoryProvider.overrideWith((Ref ref) async => snapshot),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('IU-1'), findsOneWidget);
    expect(find.textContaining('Pickup lane'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.textContaining('Earning'), findsOneWidget);
    expect(find.text('Credit'), findsNothing);

    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('No trips for this filter'), findsOneWidget);
  });

  testWidgets('trip history shows cash, online, and cancelled trips',
      (tester) async {
    await tester.pumpWidget(
      _scoped(
        const RiderHistoryScreen(),
        overrides: <Override>[
          riderOrderHistoryProvider.overrideWith(
            (Ref ref) async => RiderHistorySnapshot(
              records: <RiderHistoryRecord>[
                RiderHistoryRecord(
                  orderId: '11111111-1111-4111-8111-111111111111',
                  displayId: 'IU-CASH',
                  pickup: 'Cash pickup',
                  drop: 'Cash drop',
                  canonicalStatus: 'DELIVERED',
                  when: DateTime.utc(2026, 10, 12, 11),
                  tripFare: 120,
                  riderAmount: 90,
                  paymentLabel: 'Cash',
                  detailsLoaded: true,
                ),
                RiderHistoryRecord(
                  orderId: '22222222-2222-4222-8222-222222222222',
                  displayId: 'IU-ONLINE',
                  pickup: 'Online pickup',
                  drop: 'Online drop',
                  canonicalStatus: 'CANCELLED',
                  when: DateTime.utc(2026, 10, 11, 12, 48),
                  tripFare: 85,
                  paymentLabel: 'Online',
                  detailsLoaded: true,
                ),
              ],
              total: 2,
              failedDetails: 0,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('IU-ONLINE'), findsOneWidget);
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.textContaining('Earning'), findsOneWidget);
  });

  testWidgets('order history shows an empty list and an API error',
      (tester) async {
    await tester.pumpWidget(
      _scoped(
        const RiderHistoryScreen(),
        overrides: <Override>[
          riderOrderHistoryProvider.overrideWith(
            (Ref ref) async => const RiderHistorySnapshot(
              records: <RiderHistoryRecord>[],
              total: 0,
              failedDetails: 0,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No trips yet'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _scoped(
        const RiderHistoryScreen(),
        overrides: <Override>[
          riderOrderHistoryProvider.overrideWith(
            (Ref ref) async => throw const ApiException(
              code: 'NETWORK',
              message: 'Offline',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('history tap opens that order id', (tester) async {
    final GoRouter router = GoRouter(
      initialLocation: RiderRoutes.history,
      routes: <RouteBase>[
        GoRoute(
          path: RiderRoutes.history,
          builder: (BuildContext context, GoRouterState state) {
            return const RiderHistoryScreen();
          },
        ),
        GoRoute(
          path: RiderRoutes.pastOrder,
          builder: (BuildContext context, GoRouterState state) {
            return Text('Past ${state.uri.queryParameters['id']}');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          riderOrderHistoryProvider.overrideWith(
            (Ref ref) async => RiderHistorySnapshot(
              records: <RiderHistoryRecord>[
                RiderHistoryRecord(
                  orderId: '11111111-1111-4111-8111-111111111111',
                  displayId: 'IU-1',
                  pickup: 'Pickup lane',
                  drop: 'Drop lane',
                  canonicalStatus: 'DELIVERED',
                  when: DateTime.utc(2026, 10, 2),
                  detailsLoaded: true,
                ),
              ],
              total: 1,
              failedDetails: 0,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('IU-1'));
    await tester.pumpAndSettle();
    expect(
      find.text('Past 11111111-1111-4111-8111-111111111111'),
      findsOneWidget,
    );
  });

  testWidgets('ledger board lists transactions and not delivery stops',
      (tester) async {
    await tester.pumpWidget(
      _scoped(
        const RiderLedgerScreen(),
        overrides: <Override>[
          riderWalletLedgerProvider.overrideWith(
            (Ref ref) async => <RiderWalletLedgerEntry>[
              RiderWalletLedgerEntry(
                id: 'ledger-1',
                direction: 'CREDIT',
                amount: 85,
                entryType: 'EARNING',
                createdAt: DateTime.utc(2026, 10, 2),
                relatedOrderId: '11111111-1111-4111-8111-111111111111',
              ),
            ],
          ),
          riderLedgerTripsProvider.overrideWith(
            (Ref ref) async => const <RiderEarningRow>[],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Earning'), findsOneWidget);
    expect(find.textContaining('Credit'), findsOneWidget);
    expect(find.textContaining('Pickup'), findsNothing);
    expect(find.textContaining('Drop'), findsNothing);

    await tester.tap(find.text('Earning'));
    await tester.pumpAndSettle();
    expect(find.text('Ledger entry'), findsOneWidget);
    expect(find.text('View order'), findsOneWidget);
    expect(find.textContaining('Reference ledger-1'), findsOneWidget);
    expect(find.text('Success'), findsNothing);
    expect(find.text('Failed'), findsNothing);
  });

  testWidgets('wallet opens transaction history without leaving wallet',
      (tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/wallet',
      routes: <RouteBase>[
        GoRoute(
          path: '/wallet',
          builder: (BuildContext context, GoRouterState state) {
            return const RiderWalletScreen();
          },
        ),
        GoRoute(
          path: RiderRoutes.ledger,
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(body: Text('Ledger route'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          riderSessionProvider.overrideWith(
            (Ref ref) => _QuietRiderSession(ref),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('Add Money'), findsOneWidget);
    expect(find.text('Transaction History'), findsOneWidget);
    await tester.tap(find.text('Transaction History'));
    await tester.pumpAndSettle();
    expect(find.text('Ledger route'), findsOneWidget);
  });

  testWidgets('active delivery is shown only when a trip is running',
      (tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        riderRunningDeliveriesProvider.overrideWith((Ref ref) async {
          return RiderRunningBoard(
            running: <RiderTrackedDelivery>[
              RiderTrackedDelivery(
                order: _local('11111111-1111-4111-8111-111111111111'),
                canonicalStatus: 'IN_TRANSIT',
              ),
            ],
            clearLocalOrder: false,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(body: RiderActiveDeliverySection());
          },
        ),
        GoRoute(
          path: RiderRoutes.activeDelivery,
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(body: Text('Active delivery route'));
          },
        ),
        GoRoute(
          path: RiderRoutes.pastOrder,
          builder: (BuildContext context, GoRouterState state) {
            return Text('Past ${state.uri.queryParameters['id']}');
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
    await tester.pumpAndSettle();

    expect(find.text('Running Order'), findsOneWidget);
    expect(find.text('Continue Delivery'), findsOneWidget);
    expect(find.text('Going to Drop'), findsOneWidget);
    await tester.tap(find.text('Continue Delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Active delivery route'), findsOneWidget);
    expect(
      container.read(activeOrderProvider)?.backendOrderId,
      '11111111-1111-4111-8111-111111111111',
    );
  });

  testWidgets('no active delivery card when nothing is running',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          riderRunningDeliveriesProvider.overrideWith(
            (Ref ref) async => RiderRunningBoard.empty,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RiderActiveDeliverySection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Running Order'), findsNothing);
    expect(find.text('Continue Delivery'), findsNothing);
  });

  testWidgets('a resend stays visible without resuming pickup navigation',
      (tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        riderRunningDeliveriesProvider.overrideWith((Ref ref) async {
          return RiderRunningBoard(
            running: <RiderTrackedDelivery>[
              RiderTrackedDelivery(
                order: _local('33333333-3333-4333-8333-333333333333'),
                canonicalStatus: 'RESEND_REQUESTED',
              ),
            ],
            clearLocalOrder: false,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(body: RiderActiveDeliverySection());
          },
        ),
        GoRoute(
          path: RiderRoutes.activeDelivery,
          builder: (BuildContext context, GoRouterState state) {
            return const Text('Active delivery route');
          },
        ),
        GoRoute(
          path: RiderRoutes.pastOrder,
          builder: (BuildContext context, GoRouterState state) {
            return Text('Past ${state.uri.queryParameters['id']}');
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
    await tester.pumpAndSettle();

    expect(find.text('Resend requested'), findsOneWidget);
    expect(find.text('View order'), findsOneWidget);
    expect(find.text('Continue Delivery'), findsNothing);
    await tester.tap(find.text('View order'));
    await tester.pumpAndSettle();
    expect(
      find.text('Past 33333333-3333-4333-8333-333333333333'),
      findsOneWidget,
    );
    expect(find.text('Active delivery route'), findsNothing);
    expect(container.read(activeOrderProvider), isNull);
  });

  testWidgets('a second running order opens read-only details', (tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        riderRunningDeliveriesProvider.overrideWith((Ref ref) async {
          return RiderRunningBoard(
            running: <RiderTrackedDelivery>[
              RiderTrackedDelivery(
                order: _local('22222222-2222-4222-8222-222222222222'),
                canonicalStatus: 'ARRIVED_PICKUP',
              ),
            ],
            clearLocalOrder: false,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeOrderProvider.notifier).state =
        _local('11111111-1111-4111-8111-111111111111');
    container.read(deliveryStatusProvider.notifier).state =
        DeliveryLifecycleStatus.goingToPickup;
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(body: RiderActiveDeliverySection());
          },
        ),
        GoRoute(
          path: RiderRoutes.activeDelivery,
          builder: (BuildContext context, GoRouterState state) {
            return const Text('Active delivery route');
          },
        ),
        GoRoute(
          path: RiderRoutes.pastOrder,
          builder: (BuildContext context, GoRouterState state) {
            return Text('Past ${state.uri.queryParameters['id']}');
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue Delivery'));
    await tester.pumpAndSettle();

    expect(
      find.text('Past 22222222-2222-4222-8222-222222222222'),
      findsOneWidget,
    );
    expect(
      container.read(activeOrderProvider)?.backendOrderId,
      '11111111-1111-4111-8111-111111111111',
    );
  });

  testWidgets('past order screen loads the requested order', (tester) async {
    final _BoardRiderApi api = _BoardRiderApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          riderApiProvider.overrideWithValue(api),
          walletApiProvider.overrideWithValue(_QuietBoardWallet()),
        ],
        child: const MaterialApp(
          home: RiderPastOrderScreen(
            orderId: '11111111-1111-4111-8111-111111111111',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.reads, <String>['11111111-1111-4111-8111-111111111111']);
    expect(find.textContaining('Pickup lane'), findsOneWidget);
    expect(find.textContaining('Drop lane'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled order details do not show a delivery time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _BoardRiderApi api = _BoardRiderApi()
      ..status = 'CANCELLED'
      ..updatedAt = DateTime.utc(2026, 11, 5, 10, 20)
      ..pickup =
          'TOPS Technologies, 2, Chimanlal Girdharil Rd, near Parimal Cross Road, Shanti Sadan Society, Ellisbridge, Ahmedabad, Gujarat 380006, India';
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          riderApiProvider.overrideWithValue(api),
          walletApiProvider.overrideWithValue(_QuietBoardWallet()),
        ],
        child: const MaterialApp(
          home: RiderPastOrderScreen(
            orderId: '11111111-1111-4111-8111-111111111111',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Delivered'), findsNothing);
    expect(find.text('Delivered Time'), findsNothing);
    expect(find.text('Cancelled Time'), findsOneWidget);
    expect(find.textContaining('Ellisbridge'), findsOneWidget);
    expect(find.textContaining('Reason'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

RiderHistoryRecord _record(String status) {
  return RiderHistoryRecord(
    orderId: status,
    displayId: status,
    canonicalStatus: status,
    when: DateTime.utc(2026, 10, 2),
    detailsLoaded: true,
  );
}

RiderOrder _local(String id) {
  return RiderOrder(
    id: 'IU-${id.substring(0, 4)}',
    backendOrderId: id,
    pickup: 'Pickup lane',
    drop: 'Drop lane',
    distanceKm: 3,
    estimatedEarnings: 80,
    estimatedMinutes: 12,
    customerMaskedName: 'A.',
    customerMaskedPhone: '',
  );
}

RiderEarningRow _earning(String id, String display) {
  return RiderEarningRow(
    orderId: id,
    displayId: display,
    tripFare: 100,
    riderAmount: 80,
    frozenAt: DateTime.utc(2026, 10, 2),
  );
}

ApiOrder _api(
  String id,
  String status,
  String display, {
  DateTime? updatedAt,
  String pickupAddress = 'Pickup lane',
}) {
  return ApiOrder(
    orderId: id,
    displayId: display,
    canonicalStatus: status,
    createdAt: DateTime.utc(2026, 10, 2),
    updatedAt: updatedAt,
    pickupAddress: pickupAddress,
    dropAddress: 'Drop lane',
    tripFare: 100,
    riderAmount: 80,
  );
}

GoRouter _router(Widget home) {
  return GoRouter(
    initialLocation: '/orders',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(body: home);
        },
      ),
      GoRoute(
        path: RiderRoutes.history,
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('History route'));
        },
      ),
      GoRoute(
        path: RiderRoutes.ledger,
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Ledger route'));
        },
      ),
    ],
  );
}

Widget _scoped(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

class _BoardRiderApi extends RiderApi {
  _BoardRiderApi() : super(ApiClient(tokenStore: TokenStore()));

  final List<String> reads = <String>[];
  String status = 'DELIVERED';
  DateTime? updatedAt;
  String pickup = 'Pickup lane';

  @override
  Future<ApiOrder> getOrder(String orderId) async {
    reads.add(orderId);
    return _api(
      orderId,
      status,
      'IU-1',
      updatedAt: updatedAt,
      pickupAddress: pickup,
    );
  }

  @override
  Future<ApiOrderPaymentView?> getOrderPayment(String orderId) async {
    return null;
  }
}

class _QuietRiderSession extends RiderSessionNotifier {
  _QuietRiderSession(Ref ref) : super(ref);

  @override
  Future<void> refreshWallet() async {}
}

class _QuietBoardWallet extends WalletApi {
  _QuietBoardWallet() : super(ApiClient(tokenStore: TokenStore()));

  @override
  Future<RiderWallet> wallet() async {
    return const RiderWallet(availableBalance: 0, walletAccountId: 'wallet');
  }

  @override
  Future<RiderCod> cod() async {
    return const RiderCod(codDue: 0, suspendThreshold: 100, suspended: false);
  }

  @override
  Future<List<RiderEarningRow>> earnings() async {
    return const <RiderEarningRow>[];
  }

  @override
  Future<List<Map<String, Object?>>> walletLedger() async {
    return const <Map<String, Object?>>[];
  }
}
