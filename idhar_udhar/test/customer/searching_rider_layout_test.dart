import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/searching_rider_screen.dart';
import 'package:idhar_udhar/shared/business/business.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    OrderIds.resetDemoSequence(50);
    container.read(bookingDraftProvider.notifier)
      ..setPickup(MockData.locations[4])
      ..setDrop(MockData.locations.firstWhere((l) => l.id == 'loc_paldi'))
      ..confirmBooking();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SearchingRiderScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  for (final Size size in const [
    Size(320, 568),
    Size(390, 844),
    Size(430, 932),
    Size(900, 700),
    Size(1280, 800),
  ]) {
    testWidgets('searching rider has no overflow at $size', (tester) async {
      await pumpAt(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('Finding your rider'), findsOneWidget);
      expect(find.text('Cancel Booking'), findsOneWidget);
    });
  }
}
