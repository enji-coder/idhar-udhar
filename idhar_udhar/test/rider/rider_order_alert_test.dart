import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/widgets/rider_order_alert.dart';

void main() {
  testWidgets('foreground dialog shows the offer and blocks a second accept', (
    tester,
  ) async {
    final Completer<String?> acceptGate = Completer<String?>();
    var accepts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                RiderOrderAlert.show(
                  context,
                  order: _order(DateTime.now().add(const Duration(seconds: 30))),
                  onAccept: () {
                    accepts += 1;
                    return acceptGate.future;
                  },
                  onReject: () async => 'not used',
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('CG Road'), findsOneWidget);
    expect(find.text('Navrangpura'), findsOneWidget);
    expect(find.text('₹500'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(accepts, 1);

    acceptGate.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('CG Road'), findsNothing);
  });

  testWidgets('an expired offer disables Accept and Reject', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                RiderOrderAlert.show(
                  context,
                  order: _order(
                    DateTime.now().subtract(const Duration(seconds: 1)),
                  ),
                  onAccept: () async {
                    taps += 1;
                    return null;
                  },
                  onReject: () async {
                    taps += 1;
                    return null;
                  },
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Expired'), findsOneWidget);
    await tester.tap(find.text('Expired'));
    await tester.tap(find.text('Reject'));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('a missing pickup is not invented', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                RiderOrderAlert.show(
                  context,
                  order: _order(
                    DateTime.now().add(const Duration(seconds: 30)),
                    pickup: '',
                  ),
                  onAccept: () async => null,
                  onReject: () async => null,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Not provided'), findsOneWidget);
  });
}

RiderOrder _order(DateTime expiresAt, {String pickup = 'CG Road'}) {
  return RiderOrder(
    id: 'IU-1',
    pickup: pickup,
    drop: 'Navrangpura',
    distanceKm: 1.3,
    estimatedEarnings: 425,
    estimatedMinutes: 3,
    customerMaskedName: '',
    customerMaskedPhone: '',
    tripAmount: 500,
    expiresAt: expiresAt,
    offerId: 'offer-1',
  );
}
