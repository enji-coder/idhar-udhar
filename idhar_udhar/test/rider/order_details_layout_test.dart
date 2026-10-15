import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/rider/data/dummy/dummy_rider_repository.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/routing/rider_routes.dart';
import 'package:idhar_udhar/rider/screens/orders/order_details_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accepted order details match the delivery summary layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer();
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

    expect(find.text('CRM #129481'), findsOneWidget);
    expect(find.text('Pickup pending'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Drop'), findsOneWidget);
    expect(find.textContaining('Ruchi Apartment'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('2.1 km'), findsOneWidget);
    expect(find.text('Estimated time'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('Trip Amount'), findsOneWidget);
    expect(find.text('₹57'), findsOneWidget);
    expect(find.text('Customer Payment'), findsOneWidget);
    expect(find.text('Receiver Payment'), findsOneWidget);
    expect(find.text('UNPAID'), findsOneWidget);
    expect(find.text('Payment Method'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Anjali Patel'), findsOneWidget);
    expect(find.text('Priya Patel'), findsOneWidget);
    expect(find.text('Call Sender'), findsOneWidget);
    expect(find.text('Call Receiver'), findsOneWidget);
    expect(find.text('Start Delivery'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Start Delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Active delivery route'), findsOneWidget);
  });
}

RiderOrder _order() {
  return const RiderOrder(
    id: '129481',
    pickup:
        'Ruchi Apartment, Opp. Chintamani Parshvanath Jain Derasar, Jain Society, Jain Society Road, Paldi, Ahmedabad, Gujarat 380006, India',
    drop:
        'Gandhi Baug Society, LAW GARDEN, beside Gajjar, Ellisbridge, Ahmedabad, Gujarat 380006, India',
    distanceKm: 2.1,
    estimatedEarnings: 57,
    estimatedMinutes: 5,
    customerMaskedName: 'Anjali Patel',
    customerMaskedPhone: '9800000000',
    senderName: 'Anjali Patel',
    senderPhone: '9800000001',
    receiverName: 'Priya Patel',
    receiverPhone: '9800000002',
    tripAmount: 57,
    customerResponsibility: 0,
    receiverResponsibility: 0,
    paymentStatusLabel: 'UNPAID',
  );
}
