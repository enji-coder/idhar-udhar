import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/screens/wallet/rider_wallet_screen.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';

void main() {
  testWidgets('withdrawal asks for confirmation and ignores a second tap', (
    tester,
  ) async {
    var calls = 0;
    final Completer<void> gate = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    showRiderWalletAmountSheet(
                      context: context,
                      ref: ref,
                      title: 'Withdraw Money',
                      confirmLabel: 'Withdraw',
                      maxAmount: 200,
                      upiSaved: true,
                      onWithdraw: (amount, payoutMethod) {
                        calls += 1;
                        expect(amount, 105.4);
                        expect(payoutMethod, 'UPI');
                        return gate.future;
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '105.40');
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();

    expect(find.text('Requested withdrawal'), findsOneWidget);
    expect(find.text('Available balance'), findsOneWidget);
    expect(find.text('No withdrawal charge.'), findsOneWidget);
    expect(find.text('₹105.40'), findsWidgets);
    expect(find.text('₹0.00'), findsOneWidget);
    expect(find.text('₹200.00'), findsOneWidget);
    expect(calls, 0);

    await tester.tap(find.text('Confirm withdrawal'));
    await tester.pump();
    await tester.tap(find.text('Please wait…'));
    await tester.pump();
    expect(calls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Confirm withdrawal'), findsNothing);
  });

  testWidgets('a failed withdrawal stays open and does not claim success', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    showRiderWalletAmountSheet(
                      context: context,
                      ref: ref,
                      title: 'Withdraw Money',
                      confirmLabel: 'Withdraw',
                      maxAmount: 40,
                      upiSaved: true,
                      onWithdraw: (amount, payoutMethod) async {
                        calls += 1;
                        throw const ApiException(
                          code: 'INSUFFICIENT_BALANCE',
                          message: 'Not enough wallet balance.',
                        );
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '80');
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(find.text('Amount exceeds available balance'), findsOneWidget);
    expect(calls, 0);

    await tester.enterText(find.byType(TextField), '20');
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm withdrawal'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Not enough wallet balance.'), findsOneWidget);
    expect(find.text('Withdrawal requested'), findsNothing);
  });
}
