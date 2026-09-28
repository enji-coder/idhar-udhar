import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/customer/core/state/startup_device_pickup.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup stores the device location as the pickup', (tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        deviceLocationServiceProvider.overrideWithValue(
          _ScriptedLocation(
            result: const LocationResult.ok(
              DeviceLocation(latitude: 19.076, longitude: 72.877),
            ),
            address: const ResolvedAddress(
              latitude: 19.076,
              longitude: 72.877,
              address: 'Colaba, Mumbai',
              city: 'Mumbai',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StartupDevicePickup(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final MockLocation? pickup = container.read(bookingDraftProvider).pickup;
    expect(pickup?.latitude, 19.076);
    expect(pickup?.longitude, 72.877);
    expect(pickup?.address, 'Colaba, Mumbai');
    expect(pickup?.id, isNot(MockData.locations[4].id));
    expect(container.read(bookingDraftProvider).pickupAddressConfirmed, isFalse);
    expect(find.text('Complete Your Address'), findsNothing);
  });

  testWidgets('a manual pickup is kept when GPS returns later', (tester) async {
    final _Gate gate = _Gate();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        deviceLocationServiceProvider.overrideWithValue(
          _ScriptedLocation(
            result: const LocationResult.ok(
              DeviceLocation(latitude: 19.076, longitude: 72.877),
            ),
            address: const ResolvedAddress(
              latitude: 19.076,
              longitude: 72.877,
              address: 'Colaba, Mumbai',
            ),
            gate: gate,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    const MockLocation chosen = MockLocation(
      id: 'chosen',
      label: 'Office',
      address: 'CG Road',
      latitude: 23.03,
      longitude: 72.57,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StartupDevicePickup(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    container.read(bookingDraftProvider.notifier).setPickup(chosen);
    gate.release();
    await tester.pump();
    await tester.pump();

    final MockLocation? pickup = container.read(bookingDraftProvider).pickup;
    expect(pickup?.id, 'chosen');
    expect(pickup?.latitude, 23.03);
    expect(pickup?.longitude, 72.57);
  });
}

class _Gate {
  final Completer<void> _ready = Completer<void>();

  void release() {
    if (!_ready.isCompleted) {
      _ready.complete();
    }
  }

  Future<void> get ready => _ready.future;
}

class _ScriptedLocation extends DeviceLocationService {
  _ScriptedLocation({
    required this.result,
    required this.address,
    this.gate,
  }) : super(MapsPlatform());

  final LocationResult result;
  final ResolvedAddress address;
  final _Gate? gate;

  @override
  Future<LocationResult> currentLocation({bool requestPermission = true}) async {
    final _Gate? pending = gate;
    if (pending != null) {
      await pending.ready;
    }
    return result;
  }

  @override
  Future<ResolvedAddress?> reverse(GeoPoint point) async => address;
}
