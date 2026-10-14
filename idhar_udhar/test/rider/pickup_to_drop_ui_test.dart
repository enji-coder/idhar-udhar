import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
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
            clock: '01:20',
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
    expect(find.text('01:20'), findsOneWidget);
    expect(find.text('Waiting charge Rs 0.00'), findsOneWidget);
    expect(find.text('Rate Rs 2.50 / completed minute'), findsOneWidget);
    expect(find.text('PACKAGE PICKED UP → START TRIP'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickupWaitView(
            clock: '11:00',
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
    expect(find.text('11:00'), findsOneWidget);
    expect(find.text('Waiting charge Rs 2.50'), findsOneWidget);
  });

  testWidgets('order menu opens real details and closing it leaves navigation', (
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
                map: const ColoredBox(color: Color(0xFFE6F4F1), key: Key('nav-map')),
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
                      return RiderOrderDetailsSheet(
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
    expect(find.byKey(const ValueKey<String>('vehicle-marker-bike')), findsOneWidget);
  });

  testWidgets('a disabled pickup action does not fire twice', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickupWaitView(
            clock: '00:05',
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
    await tester.tap(find.text('PACKAGE PICKED UP → START TRIP'));
    await tester.pump();
    expect(taps, 0);
  });
}
