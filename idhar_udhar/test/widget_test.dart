import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/main.dart';

void main() {
  testWidgets('App boots into splash route', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: IdharUdharApp()));
    await tester.pump();

    expect(find.byType(IdharUdharApp), findsOneWidget);
    expect(find.textContaining('Loading'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
