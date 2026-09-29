import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/core/widgets/animated_primary_button.dart';
import 'package:idhar_udhar/customer/core/widgets/glass_text_field.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/complete_address_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MockLocation pin = MockLocation(
    id: 'pin_1',
    label: 'Shilaj',
    address: 'Shilaj, Ahmedabad',
    latitude: 23.14,
    longitude: 72.54,
  );

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required ServiceFamily family,
    required MockLocation location,
  }) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(bookingDraftProvider.notifier).setServiceFamily(family);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CompleteAddressScreen(initial: location),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Finder field(String hint) {
    return find.byWidgetPredicate(
      (Widget widget) => widget is GlassTextField && widget.hint == hint,
    );
  }

  testWidgets('pickup address requires the three fields', (tester) async {
    await pump(tester, family: ServiceFamily.twoWheeler, location: pin);
    expect(field('House / Flat / Floor / Office No.'), findsOneWidget);
    expect(field('Building / Flat / Office Name'), findsOneWidget);
    expect(field('Full Location'), findsOneWidget);
    expect(find.text('Shilaj, Ahmedabad'), findsOneWidget);
  });

  testWidgets('drop address requires the same three fields', (tester) async {
    await pump(tester, family: ServiceFamily.truck, location: pin);
    expect(field('House / Flat / Floor / Office No.'), findsOneWidget);
    expect(field('Building / Flat / Office Name'), findsOneWidget);
    expect(field('Full Location'), findsOneWidget);
  });

  testWidgets('confirm keeps coordinates and blocks a missing pin', (tester) async {
    MockLocation? confirmed;
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(bookingDraftProvider.notifier).setServiceFamily(
          ServiceFamily.twoWheeler,
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () async {
                  confirmed = await CompleteAddressScreen.open(
                    context,
                    initial: pin,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(field('House / Flat / Floor / Office No.'), 'B-12');
    await tester.enterText(field('Building / Flat / Office Name'), 'Sunrise');
    final Finder confirm = find.text('Confirm Address');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(confirmed, isNotNull);
    expect(confirmed!.latitude, 23.14);
    expect(confirmed!.longitude, 72.54);
    expect(confirmed!.address, 'Shilaj, Ahmedabad');
    expect(confirmed!.unit, 'B-12');
    expect(confirmed!.premises, 'Sunrise');
    expect(
      confirmed!.formattedAddress,
      'B-12, Sunrise, Shilaj, Ahmedabad',
    );
  });

  testWidgets('a place without coordinates cannot be confirmed', (tester) async {
    await pump(
      tester,
      family: ServiceFamily.twoWheeler,
      location: const MockLocation(
        id: 'no_pin',
        label: 'Unknown',
        address: 'Somewhere',
      ),
    );
    expect(
      find.text(
        'This place has no map pin. Choose it on the map before confirming.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<AnimatedPrimaryButton>(find.byType(AnimatedPrimaryButton)).enabled,
      isFalse,
    );
    expect(find.text('Complete Your Address'), findsOneWidget);
  });

  testWidgets('missing full location stays on the screen', (tester) async {
    await pump(tester, family: ServiceFamily.twoWheeler, location: pin);
    await tester.enterText(field('Full Location'), '');
    await tester.tap(find.text('Confirm Address'));
    await tester.pump();
    expect(find.text('Enter House / Flat / Floor / Office No.'), findsNothing);
    expect(find.text('Enter Building / Flat / Office Name'), findsNothing);
    expect(find.text('Enter Full Location'), findsOneWidget);
    expect(find.text('Complete Your Address'), findsOneWidget);
  });

  testWidgets('house and building can be left blank', (tester) async {
    MockLocation? confirmed;
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () async {
                  confirmed = await CompleteAddressScreen.open(
                    context,
                    initial: pin,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(field('House / Flat / Floor / Office No.'), '');
    await tester.enterText(field('Building / Flat / Office Name'), '');
    final Finder confirm = find.text('Confirm Address');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(confirmed, isNotNull);
    expect(confirmed!.unit, isEmpty);
    expect(confirmed!.premises, isEmpty);
    expect(confirmed!.address, 'Shilaj, Ahmedabad');
    expect(confirmed!.latitude, 23.14);
    expect(confirmed!.longitude, 72.54);
  });

  testWidgets('a valid drop address keeps the selected coordinates', (tester) async {
    const MockLocation drop = MockLocation(
      id: 'drop_1',
      label: 'Bopal',
      address: 'Bopal, Ahmedabad',
      latitude: 23.03,
      longitude: 72.47,
    );
    MockLocation? confirmed;
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(bookingDraftProvider.notifier).setPickup(pin);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () async {
                  confirmed = await CompleteAddressScreen.open(
                    context,
                    initial: drop,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(field('House / Flat / Floor / Office No.'), '4');
    await tester.enterText(field('Building / Flat / Office Name'), 'Lake View');
    final Finder confirm = find.text('Confirm Address');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(confirmed, isNotNull);
    expect(confirmed!.latitude, 23.03);
    expect(confirmed!.longitude, 72.47);
    expect(confirmed!.address, 'Bopal, Ahmedabad');
    expect(confirmed!.unit, '4');
    expect(confirmed!.premises, 'Lake View');
  });
}
