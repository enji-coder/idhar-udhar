import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/core/widgets/animated_primary_button.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/drop_location_screen.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  MockLocation named(String id) =>
      MockData.locations.firstWhere((MockLocation loc) => loc.id == id);

  Future<void> chooseDrop(
    ProviderContainer container,
    WidgetTester tester,
    int index,
    String id,
  ) async {
    container.read(bookingDraftProvider.notifier).setDropAt(index, named(id));
    await tester.pump();
  }

  Future<ProviderContainer> pumpDrop(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DropLocationScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  testWidgets('multi-drop offers only 2 and 3 location fields', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpDrop(tester);

    await tester.tap(find.text('Multiple Locations'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsNothing);
    expect(find.text('5'), findsNothing);
    expect(BookingLimits.maxDeliveryStops, 3);

    expect(find.text('Drop Location 1'), findsOneWidget);
    expect(find.text('Drop Location 2'), findsOneWidget);
    expect(find.text('Drop Location 3'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('drop-count-3')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('drop-count-3')));
    await tester.pumpAndSettle();

    expect(find.text('Drop Location 1'), findsOneWidget);
    expect(find.text('Drop Location 2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Drop Location 3'),
      80,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Drop Location 3'), findsOneWidget);

    expect(find.text('Continue'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('drop-count-2')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('drop-count-2')));
    await tester.pumpAndSettle();
    expect(find.text('Drop Location 3'), findsNothing);
    expect(find.text('Drop Location 2'), findsOneWidget);
  });

  testWidgets('drop points are independently selectable', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = await pumpDrop(tester);
    await tester.tap(find.text('Multiple Locations'));
    await tester.pumpAndSettle();

    await chooseDrop(container, tester, 0, 'loc_paldi');

    expect(container.read(bookingDraftProvider).dropAt(0)?.label, 'Paldi');
    expect(container.read(bookingDraftProvider).dropAt(1), isNull);

    await chooseDrop(container, tester, 1, 'loc_bopal');

    expect(container.read(bookingDraftProvider).dropAt(0)?.label, 'Paldi');
    expect(container.read(bookingDraftProvider).dropAt(1)?.label, 'Bopal');
  });

  testWidgets('continue requires drop 2 when only drop 1 is selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = await pumpDrop(tester);
    await tester.tap(find.text('Multiple Locations'));
    await tester.pumpAndSettle();

    await chooseDrop(container, tester, 0, 'loc_paldi');

    await tester.tap(find.byType(AnimatedPrimaryButton));
    await tester.pumpAndSettle();

    expect(
      container.read(bookingDraftProvider).incompleteStopMessage,
      'Select Drop Location 2',
    );
    expect(find.text('Select Drop Location 2'), findsWidgets);
    expect(container.read(bookingDraftProvider).activeOrder, isNull);
  });

  testWidgets('continue requires drop 3 when it is left empty', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = await pumpDrop(tester);
    await tester.tap(find.text('Multiple Locations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('drop-count-3')));
    await tester.pumpAndSettle();

    await chooseDrop(container, tester, 0, 'loc_paldi');
    await chooseDrop(container, tester, 1, 'loc_bopal');

    await tester.tap(find.byType(AnimatedPrimaryButton));
    await tester.pumpAndSettle();

    expect(
      container.read(bookingDraftProvider).incompleteStopMessage,
      'Select Drop Location 3',
    );
    expect(find.text('Select Drop Location 3'), findsWidgets);
  });

  testWidgets('keyboard insets keep drop fields reachable', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpDrop(tester);
    await tester.tap(find.text('Multiple Locations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('drop-count-3')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Drop Location 3'),
      80,
      scrollable: find.byType(Scrollable).first,
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    final Finder field = find.byKey(const ValueKey<String>('drop-field-2'));
    expect(field, findsOneWidget);
    await tester.ensureVisible(field);
    await tester.showKeyboard(field);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(field, findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('typing a drop does not create a location without a pin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = await pumpDrop(tester);
    await tester.tap(find.text('Multiple Locations'));
    await tester.pumpAndSettle();

    final Finder field = find.byKey(const ValueKey<String>('drop-field-0'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Somewhere new');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(bookingDraftProvider).dropAt(0), isNull);
    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('single location flow still shows the place list', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpDrop(tester);

    expect(find.text('Search drop location'), findsOneWidget);
    expect(find.text('Drop Location 1'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Single Location'), findsOneWidget);
  });
}
