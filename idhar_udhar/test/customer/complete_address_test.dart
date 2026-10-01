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

  Finder field(String label) {
    return find.byWidgetPredicate(
      (Widget widget) => widget is GlassTextField && widget.label == label,
    );
  }

  testWidgets('optional address fields show for every vehicle', (tester) async {
    await pump(tester, family: ServiceFamily.twoWheeler, location: pin);
    expect(
      field('House No / Floor No / Block No / Office No'),
      findsOneWidget,
    );
    expect(
      field('Building Name / Society Name / Office Name'),
      findsOneWidget,
    );
    expect(field('Complete Address'), findsOneWidget);
    expect(find.text('Shilaj, Ahmedabad'), findsOneWidget);

    await pump(tester, family: ServiceFamily.truck, location: pin);
    expect(
      field('House No / Floor No / Block No / Office No'),
      findsOneWidget,
    );
    expect(
      field('Building Name / Society Name / Office Name'),
      findsOneWidget,
    );
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
    await tester.enterText(
      field('House No / Floor No / Block No / Office No'),
      'B-12',
    );
    await tester.enterText(
      field('Building Name / Society Name / Office Name'),
      'Sunrise',
    );
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
  });

  testWidgets('house and building can both be left empty', (tester) async {
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
}
