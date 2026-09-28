import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/searching_rider_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final MockLocation pickup = MockData.locations[4];
    final MockLocation drop =
        MockData.locations.firstWhere((l) => l.id == 'loc_paldi');
    container.read(bookingDraftProvider.notifier).attachActive(
          MockOrder(
            id: 'IU-AMD-0000000050',
            status: OrderStatus.searching,
            pickup: pickup,
            drop: drop,
            vehicle: MockData.vehicles.first,
            fare: 0,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );

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
