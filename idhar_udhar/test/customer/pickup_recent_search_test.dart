import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/pickup_location_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pickup does not show recent searches', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PickupLocationScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Recent searches'), findsNothing);
    expect(find.text('No recent searches'), findsNothing);
    expect(find.text('Saved addresses'), findsOneWidget);
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Select on Map'), findsOneWidget);
  });
}
