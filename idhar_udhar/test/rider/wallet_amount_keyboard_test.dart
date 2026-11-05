import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/screens/wallet/rider_wallet_screen.dart';

void main() {
  testWidgets('Add Money amount field uses a decimal numeric keyboard', (
    tester,
  ) async {
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
                      title: 'Add Money',
                      confirmLabel: 'Add',
                      onConfirm: (_) {},
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

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.keyboardType,
      const TextInputType.numberWithOptions(decimal: true, signed: false),
    );
    expect(field.focusNode?.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), '500.50');
    expect(find.text('500.50'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12a@');
    expect(find.text('12'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Enter a valid amount'), findsOneWidget);
  });
}
