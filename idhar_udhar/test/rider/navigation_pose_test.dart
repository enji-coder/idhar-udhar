import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/features/navigation/navigation_arrow.dart';
import 'package:idhar_udhar/rider/features/navigation/navigation_pose.dart';
import 'package:idhar_udhar/rider/features/navigation/navigation_speaker.dart';
import 'package:idhar_udhar/rider/features/navigation/route_guidance.dart';
import 'package:idhar_udhar/rider/features/navigation/trip_navigation_view.dart';
import 'package:idhar_udhar/shared/maps/geo_point.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('travel updates the arrow position and heading from real movement', () {
    final NavigationPoseTracker tracker = NavigationPoseTracker();
    tracker.update(
      const DeviceLocation(
        latitude: 23.0300,
        longitude: 72.5700,
        accuracy: 6,
        speedMps: 0,
      ),
    );

    final NavigationPose? pose = tracker.update(
      const DeviceLocation(
        latitude: 23.0300,
        longitude: 72.5710,
        accuracy: 6,
        speedMps: 7,
      ),
    );

    expect(pose, isNotNull);
    expect(pose!.position.longitude, closeTo(72.5710, 0.0000001));
    expect(pose.headingDegrees, closeTo(90, 5));
  });

  test('platform bearing is used only while the rider is moving', () {
    final NavigationPoseTracker tracker = NavigationPoseTracker();
    tracker.update(
      const DeviceLocation(
        latitude: 23.0300,
        longitude: 72.5700,
        accuracy: 5,
        bearingDegrees: 90,
        speedMps: 4,
      ),
    );
    expect(tracker.current!.headingDegrees, closeTo(90, 0.1));

    tracker.update(
      const DeviceLocation(
        latitude: 23.0300,
        longitude: 72.5700,
        accuracy: 5,
        bearingDegrees: 15,
        speedMps: 0,
      ),
    );
    expect(tracker.current!.headingDegrees, closeTo(90, 0.1));
    expect(tracker.current!.position.latitude, 23.0300);
  });

  test('a poor fix does not pull the marker off the last good position', () {
    final NavigationPoseTracker tracker = NavigationPoseTracker();
    tracker.update(
      const DeviceLocation(
        latitude: 23.0300,
        longitude: 72.5700,
        accuracy: 8,
      ),
    );
    final NavigationPose? held = tracker.update(
      const DeviceLocation(
        latitude: 23.0400,
        longitude: 72.5900,
        accuracy: 140,
      ),
    );
    expect(held!.position.latitude, 23.0300);
    expect(held.position.longitude, 72.5700);
  });

  test('sub-jitter movement does not move the marker', () {
    final NavigationPoseTracker tracker = NavigationPoseTracker();
    tracker.update(
      const DeviceLocation(
        latitude: 23.0300,
        longitude: 72.5700,
        accuracy: 5,
      ),
    );
    final NavigationPose? pose = tracker.update(
      const DeviceLocation(
        latitude: 23.030012,
        longitude: 72.5700,
        accuracy: 5,
      ),
    );
    expect(pose!.position.latitude, 23.0300);
  });

  test('the arrow follows the route until the rider is actually moving', () {
    final NavigationPoseTracker tracker = NavigationPoseTracker();
    tracker.update(
      const DeviceLocation(
        latitude: 23.0300,
        longitude: 72.5700,
        accuracy: 8,
      ),
    );
    tracker.alignToRoute(const <GeoPoint>[
      GeoPoint(latitude: 23.0300, longitude: 72.5700),
      GeoPoint(latitude: 23.0310, longitude: 72.5700),
    ]);
    expect(tracker.current!.headingDegrees, closeTo(0, 2));
  });

  test('muted speaker does not record or speak a cue', () async {
    final NavigationSpeaker speaker = NavigationSpeaker(enabled: true);
    await speaker.setMuted(true);
    await speaker.cue(
      const GuidanceBanner(
        instruction: 'Head northeast',
        distanceLabel: '39 m',
        meters: 39,
        stepIndex: 0,
        speechKey: '0:Head northeast',
      ),
    );
    expect(speaker.isMuted, isTrue);
    expect(speaker.lastSpokenKey, isNull);

    await speaker.setMuted(false);
    expect(speaker.isMuted, isFalse);
  });

  test('navigation arrow asset is a png', () async {
    final Uint8List bytes = await navigationArrowPng(devicePixelRatio: 2);
    expect(bytes.length, greaterThan(32));
    expect(bytes[0], 0x89);
    expect(bytes[1], 0x50);
  });

  testWidgets('mute button toggles voice guidance state', (tester) async {
    bool muted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return TripNavigationView(
              map: const ColoredBox(color: Color(0xFFE6F4F1)),
              vehicleName: 'Bike',
              instruction: 'Head northeast',
              maneuverDistance: '39 m',
              remainingLabel: '6.1 km · 18 min',
              primaryLabel: 'ARRIVED AT PICKUP',
              onPrimary: () {},
              onMenu: () {},
              voiceMuted: muted,
              onToggleVoice: () => setState(() => muted = !muted),
            );
          },
        ),
      ),
    );

    expect(find.byTooltip('Mute voice guidance'), findsOneWidget);
    await tester.tap(find.byTooltip('Mute voice guidance'));
    await tester.pump();
    expect(find.byTooltip('Unmute voice guidance'), findsOneWidget);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Unmute voice guidance'));
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });
}
