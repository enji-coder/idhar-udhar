import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/features/navigation/arrived_drop_view.dart';
import 'package:idhar_udhar/rider/features/navigation/pickup_wait_view.dart';
import 'package:idhar_udhar/rider/features/navigation/rider_order_details_sheet.dart';
import 'package:idhar_udhar/rider/features/navigation/trip_navigation_view.dart';

void main() {
  testWidgets('waiting view shows MM:SS, zero charge, and a positive charge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickupWaitView(
            freeMinutes: 10,
            elapsedSeconds: 80,
            perMinute: '2.50',
            amount: '0.00',
            amountSource: 'preview',
            onStartTrip: () {},
            onMenu: () {},
          ),
        ),
      ),
    );
    expect(find.text('08:40'), findsOneWidget);
    expect(find.text('FREE WAITING TIME'), findsOneWidget);
    expect(find.text('Free waiting in progress'), findsOneWidget);
    expect(
      find.text('Free waiting is counting down. No fee applies until it ends.'),
      findsOneWidget,
    );
    expect(
      find.text('Your free waiting time starts after arrival is confirmed.'),
      findsNothing,
    );
    expect(find.text('No waiting fee during this time'), findsOneWidget);
    expect(find.text('₹ 2.50 / min'), findsOneWidget);
    expect(find.text('₹0.00'), findsOneWidget);
    expect(find.text('Package Picked Up'), findsOneWidget);
    expect(find.text('Start Trip'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickupWaitView(
            freeMinutes: 10,
            elapsedSeconds: 660,
            perMinute: '2.50',
            amount: '2.50',
            amountSource: 'preview',
            onStartTrip: () {},
            onMenu: () {},
          ),
        ),
      ),
    );
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('CHARGEABLE WAITING'), findsOneWidget);
    expect(find.text('Free waiting time has ended'), findsWidgets);
    expect(
      find.text(
        'Chargeable waiting time is running. Each completed minute is charged at the snapshot rate.',
      ),
      findsOneWidget,
    );
    expect(find.text('₹2.50'), findsOneWidget);
  });

  testWidgets('order menu opens real details and closing it leaves navigation',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int starts = 0;
    const RiderOrder order = RiderOrder(
      id: 'IU-9',
      crn: 'CRN1',
      pickup: 'Shivam Apartment, Satellite',
      drop: 'Vastrapur, Ahmedabad',
      distanceKm: 2.4,
      estimatedEarnings: 120,
      estimatedMinutes: 12,
      customerMaskedName: 'Rahul Sharma',
      customerMaskedPhone: '+91 98765 43210',
      vehicleName: 'Bike',
      tripAmount: 120,
      riderAmount: 102,
      packageLabel: '2 parcels',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: TripNavigationView(
                map: const ColoredBox(
                  color: Color(0xFFE6F4F1),
                  key: Key('nav-map'),
                ),
                vehicleName: 'Bike',
                instruction: 'Turn right in 200 meters',
                maneuverDistance: '200 m',
                remainingLabel: '2.4 km · 12 min',
                primaryLabel: 'ARRIVED AT PICKUP',
                onPrimary: () => starts += 1,
                onMenu: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (BuildContext sheetContext) {
                      return const RiderOrderDetailsSheet(
                        order: order,
                        statusLabel: 'Going to Pickup',
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byTooltip('Order details'));
    await tester.pumpAndSettle();
    expect(find.text('Shivam Apartment, Satellite'), findsOneWidget);
    expect(find.text('Vastrapur, Ahmedabad'), findsOneWidget);
    expect(find.text('Bike'), findsWidgets);
    expect(find.textContaining('IU-9'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Turn right in 200 meters'), findsOneWidget);
    expect(find.byKey(const Key('nav-map')), findsOneWidget);
    expect(starts, 0);
    expect(
      find.byKey(const ValueKey<String>('vehicle-marker-bike')),
      findsOneWidget,
    );
  });

  testWidgets('a disabled pickup action does not fire twice', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickupWaitView(
            freeMinutes: 10,
            elapsedSeconds: 5,
            perMinute: '1.00',
            amount: '0.00',
            amountSource: 'preview',
            primaryEnabled: false,
            onStartTrip: () => taps += 1,
            onMenu: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Package Picked Up'));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('free time counts down and then shows the chargeable minute', (
    tester,
  ) async {
    Future<void> show(int elapsed, String amount) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PickupWaitView(
              freeMinutes: 10,
              elapsedSeconds: elapsed,
              perMinute: '2.50',
              amount: amount,
              amountSource: 'preview',
              onStartTrip: () {},
              onMenu: () {},
            ),
          ),
        ),
      );
    }

    await show(0, '0.00');
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Free waiting in progress'), findsOneWidget);
    expect(
      find.text('Your free waiting time starts after arrival is confirmed.'),
      findsNothing,
    );

    await show(1, '0.00');
    expect(find.text('09:59'), findsOneWidget);
    expect(find.text('₹0.00'), findsOneWidget);

    await show(660, '2.50');
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('Free waiting time has ended'), findsWidgets);
    expect(find.text('₹2.50'), findsOneWidget);
  });

  testWidgets('missing rules keep the screen and do not invent a countdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickupWaitView(
            freeMinutes: 0,
            elapsedSeconds: null,
            rulesLoaded: false,
            perMinute: '',
            amount: '0.00',
            amountSource: 'preview',
            arrivalMissing: true,
            error: 'Waiting details for this order are not available.',
            onStartTrip: () {},
            onMenu: () {},
          ),
        ),
      ),
    );
    expect(find.text('--:--'), findsOneWidget);
    expect(find.text('We could not find that.'), findsNothing);
    expect(
      find.text('Waiting details for this order are not available.'),
      findsOneWidget,
    );
    expect(find.text("You've arrived at the pickup location!"), findsOneWidget);
    expect(find.text('Package Picked Up'), findsOneWidget);
    expect(find.text('Start Trip'), findsOneWidget);
  });

  testWidgets(
      'arrival not confirmed explains that free waiting has not started', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PickupWaitView(
            freeMinutes: 10,
            elapsedSeconds: null,
            perMinute: '2.50',
            amount: '0.00',
            amountSource: 'preview',
            arrivalMissing: true,
            onStartTrip: _noop,
            onMenu: _noop,
          ),
        ),
      ),
    );
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Customer not here yet'), findsOneWidget);
    expect(
      find.text('Your free waiting time starts after arrival is confirmed.'),
      findsOneWidget,
    );
    expect(find.text('Free waiting in progress'), findsNothing);
  });

  testWidgets('a missing waiting rate is not shown as a zero charge', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PickupWaitView(
            freeMinutes: 10,
            elapsedSeconds: 30,
            perMinute: '',
            amount: '',
            amountSource: 'preview',
            rateAvailable: false,
            onStartTrip: _noop,
            onMenu: _noop,
          ),
        ),
      ),
    );
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('Unavailable'), findsNWidgets(2));
    expect(find.text('₹0.00'), findsNothing);
    expect(find.text('₹ 0.00 / min'), findsNothing);
  });

  testWidgets('drop arrival keeps the receiver action off delivery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var receiverTaps = 0;
    var arrivedTaps = 0;
    var navigations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArrivedDropView(
            orderTitle: 'IU-AMD-0000000157',
            pickup: 'Sonal Complex, Vastrapur',
            drop: '212, Drive In Rd, Ahmedabad',
            packageLabel: '1 Item',
            distanceLabel: '12.5 km',
            etaLabel: '18 min',
            onMenu: () {},
            onNavigate: () => navigations += 1,
            onReceiverUnavailable: () => receiverTaps += 1,
            onArrived: () => arrivedTaps += 1,
          ),
        ),
      ),
    );

    expect(find.text('Drop Location'), findsOneWidget);
    expect(find.text('Receiver not available?'), findsOneWidget);
    expect(find.text('ARRIVED AT DROP LOCATION'), findsOneWidget);
    expect(find.text('View Details'), findsNothing);
    expect(find.text('212, Drive In Rd, Ahmedabad'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Receiver not available?'));
    await tester.pump();
    expect(receiverTaps, 1);
    expect(arrivedTaps, 0);
    expect(navigations, 0);

    await tester.tap(find.text('Start navigation to drop'));
    await tester.pump();
    expect(navigations, 1);
    expect(arrivedTaps, 0);

    await tester.tap(find.text('ARRIVED AT DROP LOCATION'));
    await tester.pump();
    expect(arrivedTaps, 1);
    expect(receiverTaps, 1);
  });
}

void _noop() {}
