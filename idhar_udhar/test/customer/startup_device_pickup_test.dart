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

  testWidgets('startup stores GPS separately from the selected pickup', (
    tester,
  ) async {
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

    final BookingDraft draft = container.read(bookingDraftProvider);
    expect(draft.deviceLocation?.latitude, 19.076);
    expect(draft.deviceLocation?.longitude, 72.877);
    expect(draft.deviceLocation?.address, 'Colaba, Mumbai');
    expect(draft.deviceLocation?.id, 'gps_pickup');
    expect(draft.pickup?.id, MockData.locations[4].id);
    expect(draft.pickup?.latitude, isNot(19.076));
  });

  testWidgets('startup caches coordinates before reverse geocode finishes', (
    tester,
  ) async {
    final _Gate reverseGate = _Gate();
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
            reverseGate: reverseGate,
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

    BookingDraft draft = container.read(bookingDraftProvider);
    expect(draft.deviceLocation?.latitude, 19.076);
    expect(draft.deviceLocation?.longitude, 72.877);
    expect(draft.deviceLocation?.address, isEmpty);
    expect(draft.pickup?.id, MockData.locations[4].id);

    reverseGate.release();
    await tester.pump();
    await tester.pump();

    draft = container.read(bookingDraftProvider);
    expect(draft.deviceLocation?.address, 'Colaba, Mumbai');
    expect(draft.pickup?.latitude, isNot(19.076));
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
      latitude: 12.9716,
      longitude: 77.5946,
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

    final BookingDraft draft = container.read(bookingDraftProvider);
    expect(draft.pickup?.id, 'chosen');
    expect(draft.pickup?.latitude, 12.9716);
    expect(draft.pickup?.longitude, 77.5946);
    expect(draft.deviceLocation?.latitude, 19.076);
    expect(draft.deviceLocation?.longitude, 72.877);
    expect(draft.deviceLocation?.id, isNot('chosen'));
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
    this.reverseGate,
  }) : super(MapsPlatform());

  final LocationResult result;
  final ResolvedAddress address;
  final _Gate? gate;
  final _Gate? reverseGate;

  @override
  Future<LocationResult> currentLocation({
    bool requestPermission = true,
  }) async {
    final _Gate? pending = gate;
    if (pending != null) {
      await pending.ready;
    }
    return result;
  }

  @override
  Future<ResolvedAddress?> reverse(GeoPoint point) async {
    final _Gate? pending = reverseGate;
    if (pending != null) {
      await pending.ready;
    }
    return address;
  }
}
