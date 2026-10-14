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
    var rejects = 0;
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
                  onReject: () async {
                    rejects += 1;
                    return 'not used';
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

    expect(find.text('CG Road'), findsOneWidget);
    expect(find.text('Navrangpura'), findsOneWidget);
    expect(find.text('Rs. 500'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('ETA'), findsOneWidget);
    expect(find.text('Trip Fare'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    final int started = _secondsShowing(tester);
    expect(started, inInclusiveRange(1, 30));
    await tester.pump();
    expect(_secondsShowing(tester), started);

    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.tap(find.text('Reject'));
    await tester.pump();
    expect(accepts, 1);
    expect(rejects, 0);

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
    expect(find.text('0s'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.tap(find.text('Reject'));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('reject uses the reject callback and blocks a second tap', (
    tester,
  ) async {
    final Completer<String?> rejectGate = Completer<String?>();
    var rejects = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                RiderOrderAlert.show(
                  context,
                  order: _order(DateTime.now().add(const Duration(seconds: 30))),
                  onAccept: () async => 'not used',
                  onReject: () {
                    rejects += 1;
                    return rejectGate.future;
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
    await tester.tap(find.text('Reject'));
    await tester.pump();
    await tester.tap(find.text('Reject'));
    await tester.pump();
    expect(rejects, 1);
    rejectGate.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('CG Road'), findsNothing);
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
    expect(find.text('—'), findsWidgets);
    expect(find.textContaining('CG Road'), findsNothing);
  });
}

int _secondsShowing(WidgetTester tester) {
  final Text timer = tester.widget<Text>(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text && RegExp(r'^\d+s$').hasMatch(widget.data ?? ''),
    ),
  );
  return int.parse(timer.data!.replaceAll('s', ''));
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
