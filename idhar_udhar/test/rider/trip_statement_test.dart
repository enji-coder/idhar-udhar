import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/screens/orders/rider_trip_statement.dart';

void main() {
  testWidgets('cash trip statement shows the collected fare and company share', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderTripStatement(
            crn: 'IU-CRN-AHM-0000000001',
            tripAt: DateTime.utc(2026, 11, 6, 4, 30),
            pickupAddress: 'Pickup lane',
            dropAddress: 'Drop lane',
            tripFare: 124,
            riderAmount: 105.40,
            companyAmount: 18.60,
            settlementStatus: 'CASH',
            settlementState: 'SETTLED',
            cashCollected: 124,
            walletCredited: 0,
            codApplied: 0,
            walletCompanyDebit: 18.60,
          ),
        ),
      ),
    );

    expect(find.text('IU-CRN-AHM-0000000001'), findsOneWidget);
    expect(find.text('₹124.00'), findsWidgets);
    expect(find.text('₹105.40'), findsWidgets);
    expect(find.text('₹18.60'), findsWidgets);
    expect(find.text('+₹124.00'), findsOneWidget);
    expect(find.text('-₹18.60'), findsOneWidget);
    expect(find.text('WALLET'), findsOneWidget);
    expect(find.text('SETTLED'), findsOneWidget);
    expect(find.text('Cash kept by you'), findsOneWidget);
    expect(find.text('WALLET CREDIT'), findsNothing);
  });

  testWidgets('online trip statement shows a pending wallet credit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderTripStatement(
            crn: 'IU-CRN-AHM-0000000002',
            tripAt: DateTime.utc(2026, 11, 6, 5, 0),
            pickupAddress: 'Pickup lane',
            dropAddress: 'Drop lane',
            tripFare: 124,
            riderAmount: 105.40,
            companyAmount: 18.60,
            settlementStatus: 'PENDING',
            settlementState: 'PENDING',
            cashCollected: 0,
            walletCredited: 0,
            codApplied: 0,
          ),
        ),
      ),
    );

    expect(find.text('Pending online payment'), findsWidgets);
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('CASH COLLECTED'), findsNothing);
    expect(find.text('₹105.40'), findsWidgets);
  });
}
