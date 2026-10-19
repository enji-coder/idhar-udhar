import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/features/navigation/navigation_arrow.dart';
import 'package:idhar_udhar/rider/features/navigation/navigation_pose.dart';
import 'package:idhar_udhar/rider/features/navigation/navigation_speaker.dart';
import 'package:idhar_udhar/rider/features/navigation/route_guidance.dart';
import 'package:idhar_udhar/rider/features/navigation/trip_navigation_view.dart';
import 'package:idhar_udhar/shared/maps/geo_point.dart';
import 'package:idhar_udhar/shared/maps/navigation_follow.dart';

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

  test('a stale GPS fix does not become the current position', () {
    final NavigationPoseTracker tracker = NavigationPoseTracker();
    final DateTime now = DateTime.utc(2026, 10, 19, 8);
    tracker.update(
      DeviceLocation(
        latitude: 23.03,
        longitude: 72.57,
        accuracy: 8,
        timeMillis: now.millisecondsSinceEpoch,
      ),
      now: now,
    );
    final NavigationPose? pose = tracker.update(
      DeviceLocation(
        latitude: 23.04,
        longitude: 72.58,
        accuracy: 8,
        timeMillis: now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      ),
      now: now,
    );
    expect(pose!.position.latitude, 23.03);
    expect(tracker.lastQuality, NavigationFixQuality.stale);
    expect(tracker.fixNotice, contains('stale'));
  });

  test('the first coarse fix is kept when nothing better exists', () {
    final NavigationPoseTracker tracker = NavigationPoseTracker();
    final NavigationPose? pose = tracker.update(
      const DeviceLocation(
        latitude: 23.03,
        longitude: 72.57,
        accuracy: 140,
      ),
    );
    expect(pose!.position.latitude, 23.03);
    expect(tracker.lastQuality, NavigationFixQuality.approximate);
  });

  test('a fresh coarse fix replaces a position that has gone stale', () {
    final NavigationPoseTracker tracker = NavigationPoseTracker();
    final DateTime start = DateTime.utc(2026, 10, 19, 8);
    tracker.update(
      DeviceLocation(
        latitude: 23.03,
        longitude: 72.57,
        accuracy: 8,
        timeMillis: start.millisecondsSinceEpoch,
      ),
      now: start,
    );
    final DateTime later = start.add(const Duration(seconds: 70));
    final NavigationPose? pose = tracker.update(
      DeviceLocation(
        latitude: 23.031,
        longitude: 72.57,
        accuracy: 110,
        timeMillis: later.millisecondsSinceEpoch,
      ),
      now: later,
    );
    expect(pose!.position.latitude, closeTo(23.031, 0.00001));
    expect(tracker.lastQuality, NavigationFixQuality.approximate);
  });

  test('an uncertain GPS bearing does not override course over ground', () {
    final NavigationPoseTracker tracker = NavigationPoseTracker();
    tracker.update(
      const DeviceLocation(
        latitude: 23.03,
        longitude: 72.57,
        accuracy: 6,
      ),
    );
    final NavigationPose? pose = tracker.update(
      const DeviceLocation(
        latitude: 23.03,
        longitude: 72.571,
        accuracy: 6,
        bearingDegrees: 180,
        bearingAccuracyDegrees: 55,
        speedMps: 7,
      ),
    );
    expect(pose!.headingDegrees, closeTo(90, 8));
  });

  test('an app camera start does not pause follow', () {
    final NavigationFollowGate gate = NavigationFollowGate();
    gate.onCameraIdle();
    gate.beginAppMove();
    expect(gate.onPlatformMoveStarted(), isFalse);
    expect(gate.paused, isFalse);
  });

  test('a manual camera start pauses follow and resume restores it', () {
    final NavigationFollowGate gate = NavigationFollowGate();
    gate.onCameraIdle();
    expect(gate.onPlatformMoveStarted(), isTrue);
    expect(gate.paused, isTrue);

    gate.resume();
    expect(gate.paused, isFalse);
    gate.beginAppMove();
    expect(gate.onPlatformMoveStarted(), isFalse);
    expect(gate.paused, isFalse);
    expect(gate.onPlatformMoveStarted(), isTrue);
    expect(gate.paused, isTrue);
  });

  test('a second start during an app move is a manual interruption', () {
    final NavigationFollowGate gate = NavigationFollowGate();
    gate.onCameraIdle();
    gate.beginAppMove();
    expect(gate.onPlatformMoveStarted(), isFalse);
    expect(gate.onPlatformMoveStarted(), isTrue);
    expect(gate.paused, isTrue);
  });

  test('the opening camera start is not treated as a gesture', () {
    final NavigationFollowGate gate = NavigationFollowGate();
    expect(gate.onPlatformMoveStarted(), isFalse);
    expect(gate.paused, isFalse);
    gate.onCameraIdle();
    expect(gate.onPlatformMoveStarted(), isTrue);
    expect(gate.paused, isTrue);
  });

  test('an app move that never starts does not hide the next gesture', () {
    final NavigationFollowGate gate = NavigationFollowGate();
    gate.onCameraIdle();
    gate.beginAppMove();
    gate.cancelAppMove();
    expect(gate.onPlatformMoveStarted(), isTrue);
    expect(gate.paused, isTrue);
  });

  test('camera idle does not turn an in-flight app move into a gesture', () {
    final NavigationFollowGate gate = NavigationFollowGate();
    gate.onCameraIdle();
    gate.beginAppMove();
    gate.onCameraIdle();
    expect(gate.onPlatformMoveStarted(), isFalse);
    expect(gate.paused, isFalse);
  });

  test('only one app start is expected at a time', () {
    final NavigationFollowGate gate = NavigationFollowGate();
    gate.onCameraIdle();
    expect(gate.beginAppMove(), isTrue);
    expect(gate.beginAppMove(), isFalse);
    expect(gate.onPlatformMoveStarted(), isFalse);
    expect(gate.hasPendingAppStart, isFalse);
    expect(gate.onPlatformMoveStarted(), isTrue);
    expect(gate.paused, isTrue);
  });

  test('a start while follow is off does not hide the next pan', () {
    final NavigationFollowGate gate = NavigationFollowGate();
    gate.onCameraIdle();
    gate.beginAppMove();
    expect(gate.onPlatformMoveStarted(followEnabled: false), isFalse);
    expect(gate.paused, isFalse);
    expect(gate.hasPendingAppStart, isFalse);
    expect(gate.onPlatformMoveStarted(followEnabled: true), isTrue);
    expect(gate.paused, isTrue);
  });

  test('a newer target waits until the in-flight animation is idle', () {
    final NavigationCameraEpisode episode = NavigationCameraEpisode();
    episode.follow.onCameraIdle();
    expect(episode.requestAppMove(), isTrue);
    expect(episode.requestAppMove(), isFalse);
    episode.queueLatest();
    expect(episode.onMoveStarted(followEnabled: true), isFalse);
    expect(episode.onIdle(followEnabled: true), isTrue);
    expect(episode.inFlight, isFalse);
    expect(episode.requestAppMove(), isTrue);
    expect(episode.onMoveStarted(followEnabled: true), isFalse);
    expect(episode.onIdle(followEnabled: true), isFalse);
    expect(episode.onMoveStarted(followEnabled: true), isTrue);
    expect(episode.follow.paused, isTrue);
  });

  test('a pan during an app animation does not apply the queued target', () {
    final NavigationCameraEpisode episode = NavigationCameraEpisode();
    episode.follow.onCameraIdle();
    expect(episode.requestAppMove(), isTrue);
    episode.queueLatest();
    expect(episode.onMoveStarted(followEnabled: true), isFalse);
    expect(episode.onMoveStarted(followEnabled: true), isTrue);
    expect(episode.onIdle(followEnabled: true), isFalse);
    expect(episode.inFlight, isFalse);
  });

  test('a failed camera call does not hide the next pan or compass tap', () {
    final NavigationCameraEpisode episode = NavigationCameraEpisode();
    episode.follow.onCameraIdle();
    expect(episode.requestAppMove(), isTrue);
    episode.failAppMove();
    expect(episode.inFlight, isFalse);
    expect(episode.follow.hasPendingAppStart, isFalse);
    expect(episode.onMoveStarted(followEnabled: true), isTrue);
    expect(episode.follow.paused, isTrue);
  });

  test('disabling follow consumes the pending app start', () {
    final NavigationCameraEpisode episode = NavigationCameraEpisode();
    episode.follow.onCameraIdle();
    expect(episode.requestAppMove(), isTrue);
    episode.queueLatest();
    expect(episode.onMoveStarted(followEnabled: false), isFalse);
    expect(episode.follow.paused, isFalse);
    expect(episode.onIdle(followEnabled: false), isFalse);
    expect(episode.follow.hasPendingAppStart, isFalse);
    expect(episode.onMoveStarted(followEnabled: true), isTrue);
    expect(episode.follow.paused, isTrue);
  });

  test('a gesture before the first idle cannot be distinguished', () {
    final NavigationCameraEpisode episode = NavigationCameraEpisode();
    expect(episode.onMoveStarted(followEnabled: true), isFalse);
    expect(episode.follow.paused, isFalse);
    expect(episode.onIdle(followEnabled: true), isFalse);
    expect(episode.onMoveStarted(followEnabled: true), isTrue);
    expect(episode.follow.paused, isTrue);
  });

  test('idle before the app start keeps the episode open', () {
    final NavigationCameraEpisode episode = NavigationCameraEpisode();
    episode.follow.onCameraIdle();
    expect(episode.requestAppMove(), isTrue);
    episode.queueLatest();
    expect(episode.onIdle(followEnabled: true), isFalse);
    expect(episode.inFlight, isTrue);
    expect(episode.onMoveStarted(followEnabled: true), isFalse);
    expect(episode.onIdle(followEnabled: true), isTrue);
  });

  test('navigation camera buckets bearing and tilts only while moving', () {
    expect(NavigationCamera.bearingBucket(0), 0);
    expect(NavigationCamera.bearingBucket(90), 18);
    expect(NavigationCamera.tiltForSpeed(0), 0);
    expect(NavigationCamera.tiltForSpeed(2), NavigationCamera.movingTilt);
  });

  testWidgets('order details menu stays on the navigation screen', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TripNavigationView(
          map: const ColoredBox(color: Color(0xFFE6F4F1)),
          vehicleName: 'Bike',
          instruction: 'Head northeast',
          maneuverDistance: '39 m',
          remainingLabel: '6.1 km · 18 min',
          primaryLabel: 'ARRIVED AT PICKUP',
          onPrimary: () {},
          onMenu: () => opened = true,
        ),
      ),
    );
    expect(find.byTooltip('Order details'), findsOneWidget);
    expect(find.text('ARRIVED AT PICKUP'), findsOneWidget);
    await tester.tap(find.byTooltip('Order details'));
    expect(opened, isTrue);
  });
}
