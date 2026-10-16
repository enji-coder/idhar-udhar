import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/features/navigation/route_guidance.dart';
import 'package:idhar_udhar/rider/features/navigation/vehicle_marker.dart';
import 'package:idhar_udhar/rider/features/navigation/waiting_clock.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

void main() {
  test('waiting clock is MM:SS and resumes from the server timestamp', () {
    expect(formatWaitingClock(5), '00:05');
    expect(formatWaitingClock(80), '01:20');
    expect(formatWaitingClock(599), '09:59');
    expect(formatWaitingClock(600), '10:00');
    expect(formatWaitingClock(null), '--:--');

    final DateTime arrival = DateTime.utc(2026, 10, 14, 8);
    final DateTime serverNow = DateTime.utc(2026, 10, 14, 8, 1, 20);
    final DateTime fetchedAt = DateTime.utc(2026, 10, 14, 8, 1, 20);
    expect(
      waitingElapsedSeconds(
        arrivalAt: arrival,
        serverNow: serverNow,
        fetchedAt: fetchedAt,
        now: DateTime.utc(2026, 10, 14, 8, 1, 25),
      ),
      85,
    );
    expect(
      formatWaitingClock(
        waitingElapsedSeconds(
          arrivalAt: arrival,
          serverNow: serverNow,
          fetchedAt: fetchedAt,
          now: fetchedAt,
        ),
      ),
      '01:20',
    );
  });

  test('free waiting remaining uses the configured minutes', () {
    expect(
      freeWaitingRemainingSeconds(elapsedSeconds: 80, freeMinutes: 10),
      520,
    );
    expect(
      freeWaitingRemainingSeconds(elapsedSeconds: 600, freeMinutes: 10),
      0,
    );
    expect(
      freeWaitingRemainingSeconds(elapsedSeconds: 660, freeMinutes: 10),
      0,
    );
  });

  test('countdown and charge follow the snapshot, not a fixed category', () {
    expect(
      formatWaitingClock(
        freeWaitingRemainingSeconds(elapsedSeconds: 0, freeMinutes: 10),
      ),
      '10:00',
    );
    expect(
      formatWaitingClock(
        freeWaitingRemainingSeconds(elapsedSeconds: 1, freeMinutes: 10),
      ),
      '09:59',
    );
    expect(
      formatWaitingClock(
        freeWaitingRemainingSeconds(elapsedSeconds: 0, freeMinutes: 5),
      ),
      '05:00',
    );
    expect(
      chargeableWaitingSeconds(elapsedSeconds: 600, freeMinutes: 10),
      0,
    );
    expect(
      chargeableWaitingSeconds(elapsedSeconds: 11 * 60, freeMinutes: 10),
      60,
    );
    expect(
      previewWaitingAmount(
        elapsedSeconds: 10 * 60,
        freeMinutes: 10,
        perMinute: '2.50',
      ),
      '0.00',
    );
    expect(
      previewWaitingAmount(
        elapsedSeconds: 10 * 60 + 59,
        freeMinutes: 10,
        perMinute: '2.50',
      ),
      '0.00',
    );
    expect(
      previewWaitingAmount(
        elapsedSeconds: 11 * 60,
        freeMinutes: 10,
        perMinute: '2.50',
      ),
      '2.50',
    );
    expect(
      previewWaitingAmount(
        elapsedSeconds: 12 * 60 + 30,
        freeMinutes: 4,
        perMinute: '1.25',
      ),
      '10.00',
    );
    expect(
      previewWaitingAmount(
        elapsedSeconds: 90,
        freeMinutes: 10,
        perMinute: 'not-a-rate',
      ),
      isNull,
    );
  });

  test('resume uses the arrival timestamp instead of restarting free time', () {
    final DateTime arrival = DateTime.utc(2026, 10, 14, 8);
    final DateTime serverNow = DateTime.utc(2026, 10, 14, 8, 4);
    final DateTime fetchedAt = DateTime.utc(2026, 10, 14, 8, 4);
    final int elapsed = waitingElapsedSeconds(
      arrivalAt: arrival,
      serverNow: serverNow,
      fetchedAt: fetchedAt,
      now: DateTime.utc(2026, 10, 14, 8, 4, 2),
    );
    expect(elapsed, 242);
    expect(
      formatWaitingClock(
        freeWaitingRemainingSeconds(elapsedSeconds: elapsed, freeMinutes: 10),
      ),
      '05:58',
    );
  });

  test('pickup-wait mapping keeps each category snapshot and a missing field',
      () {
    final PickupWaitSnapshot bike = PickupWaitSnapshot.fromJson(
      <String, Object?>{
        'timestamp_status': 'ok',
        'arrival_at': '2026-10-14T08:00:00.000Z',
        'server_now': '2026-10-14T08:01:00.000Z',
        'initial_waiting_minutes': 10,
        'waiting_charge_per_minute': '2.50',
        'elapsed_seconds': 60,
        'amount': '0.00',
        'amount_source': 'preview',
        'vehicle_category_name': 'Bike',
      },
    );
    expect(bike.hasWaitingRules, isTrue);
    expect(bike.initialWaitingMinutes, 10);
    expect(bike.perMinute, '2.50');
    expect(bike.arrivalMissing, isFalse);

    final PickupWaitSnapshot van = PickupWaitSnapshot.fromJson(
      <String, Object?>{
        'timestamp_status': 'ok',
        'arrival_at': '2026-10-14T08:00:00.000Z',
        'initial_waiting_minutes': '4',
        'waiting_charge_per_minute': 1.5,
        'vehicle_category_name': 'Van',
      },
    );
    expect(van.initialWaitingMinutes, 4);
    expect(van.hasWaitingRate, isTrue);
    expect(van.perMinute, '1.50');

    final PickupWaitSnapshot explicitZero = PickupWaitSnapshot.fromJson(
      <String, Object?>{
        'initial_waiting_minutes': 10,
        'waiting_charge_per_minute': 0,
      },
    );
    expect(explicitZero.hasWaitingRules, isTrue);
    expect(explicitZero.hasWaitingRate, isTrue);
    expect(explicitZero.perMinute, '0.00');

    final PickupWaitSnapshot missingRate = PickupWaitSnapshot.fromJson(
      <String, Object?>{
        'initial_waiting_minutes': 10,
        'amount': '0.00',
      },
    );
    expect(missingRate.hasWaitingRules, isTrue);
    expect(missingRate.hasWaitingRate, isFalse);
    expect(missingRate.perMinute, isEmpty);

    final PickupWaitSnapshot invalidRate = PickupWaitSnapshot.fromJson(
      <String, Object?>{
        'initial_waiting_minutes': 10,
        'waiting_charge_per_minute': 'not-a-rate',
      },
    );
    expect(invalidRate.hasWaitingRate, isFalse);
    expect(invalidRate.perMinute, isEmpty);

    final PickupWaitSnapshot missing = PickupWaitSnapshot.fromJson(
      <String, Object?>{
        'timestamp_status': 'missing_arrival',
        'amount': '0.00',
      },
    );
    expect(missing.hasWaitingRules, isFalse);
    expect(missing.initialWaitingMinutes, 0);
    expect(missing.arrivalMissing, isTrue);

    expect(
      waitingFailureMessage(
        code: 'NOT_FOUND',
        message: 'We could not find that.',
      ),
      'Waiting details for this order are not available.',
    );
    expect(
      waitingFailureMessage(code: 'FARE_NOT_CONFIRMED'),
      'Waiting rules for this order are not available.',
    );
  });

  test('vehicle marker follows the order category and is not a car', () {
    expect(vehicleMarkerFor('Scooty'), RiderVehicleMarker.scooter);
    expect(vehicleMarkerFor('Bike'), RiderVehicleMarker.bike);
    expect(vehicleMarkerFor(''), RiderVehicleMarker.parcel);
    expect(
      vehicleMarkerIcon(RiderVehicleMarker.scooter),
      isNot(vehicleMarkerIcon(RiderVehicleMarker.truck)),
    );
  });

  test('voice cue is not repeated for the same turn', () {
    const GuidanceBanner first = GuidanceBanner(
      instruction: 'Turn right',
      distanceLabel: '180 m',
      meters: 180,
      stepIndex: 1,
      speechKey: '1:Turn right',
    );
    const GuidanceBanner far = GuidanceBanner(
      instruction: 'Turn right',
      distanceLabel: '400 m',
      meters: 400,
      stepIndex: 1,
      speechKey: '1:Turn right',
    );
    expect(shouldSpeakCue(banner: far, lastSpokenKey: null), isFalse);
    expect(shouldSpeakCue(banner: first, lastSpokenKey: '0:Head out'), isTrue);
    expect(
      shouldSpeakCue(banner: first, lastSpokenKey: '1:Turn right'),
      isFalse,
    );
  });

  test('guidance parses a turn and the pickup route points', () {
    final GuidedRoute? guided = RoutesService.parseGuidance(<String, Object?>{
      'routes': <Object?>[
        <String, Object?>{
          'distanceMeters': 1200,
          'duration': '300s',
          'polyline': <String, Object?>{
            'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
          },
          'legs': <Object?>[
            <String, Object?>{
              'steps': <Object?>[
                <String, Object?>{
                  'distanceMeters': 200,
                  'navigationInstruction': <String, Object?>{
                    'maneuver': 'TURN_RIGHT',
                    'instructions': 'Turn right onto CG Road',
                  },
                  'endLocation': <String, Object?>{
                    'latLng': <String, Object?>{
                      'latitude': 23.03,
                      'longitude': 72.57,
                    },
                  },
                },
              ],
            },
          ],
        },
      ],
    });
    expect(guided, isNotNull);
    expect(guided!.route.points.length, greaterThan(1));
    expect(guided.steps.single.instruction, 'Turn right onto CG Road');
    final GuidanceBanner? banner = guidanceBanner(
      steps: guided.steps,
      position: null,
    );
    expect(banner!.instruction, 'Turn right onto CG Road');
  });

  test('sequential guidance approaches then advances past a maneuver end', () {
    final List<RouteStep> steps = _lineSteps();
    final GeoPoint approaching = GeoPoint(
      latitude: steps[0].end.latitude - 0.0018,
      longitude: steps[0].end.longitude,
    );
    final GuidanceBanner? approachingBanner = guidanceBanner(
      steps: steps,
      position: approaching,
    );
    expect(approachingBanner!.stepIndex, 0);
    expect(approachingBanner.instruction, 'Turn right onto CG Road');
    expect(approachingBanner.meters, greaterThan(35));

    final GeoPoint atEnd = steps[0].end;
    final GuidanceBanner? arrivedBanner = guidanceBanner(
      steps: steps,
      position: atEnd,
    );
    expect(arrivedBanner!.stepIndex, 1);
    expect(arrivedBanner.instruction, 'Turn left onto Ashram Road');

    // Past step 0 by more than arrive radius, but still nearer step 0 than step 1.
    // Old nearest-end logic stayed on step 0; sequential must advance.
    final GeoPoint pastFirst = GeoPoint(
      latitude: steps[0].end.latitude + 0.0005,
      longitude: steps[0].end.longitude,
    );
    expect(metersBetween(pastFirst, steps[0].end), greaterThan(35));
    expect(
      metersBetween(pastFirst, steps[0].end),
      lessThan(metersBetween(pastFirst, steps[1].end)),
    );
    final GuidanceBanner? pastBanner = guidanceBanner(
      steps: steps,
      position: pastFirst,
    );
    expect(pastBanner!.stepIndex, 1);
    expect(pastBanner.instruction, 'Turn left onto Ashram Road');
  });

  test(
      'sequential guidance does not jump to a geographically nearer later step',
      () {
    // Step 2 ends near the start (loop fold). Nearest-end would pick it early.
    const List<RouteStep> steps = <RouteStep>[
      RouteStep(
        instruction: 'Head north',
        maneuver: 'DEPART',
        distanceMeters: 200,
        end: GeoPoint(latitude: 23.0300, longitude: 72.5700),
      ),
      RouteStep(
        instruction: 'Turn right',
        maneuver: 'TURN_RIGHT',
        distanceMeters: 200,
        end: GeoPoint(latitude: 23.0320, longitude: 72.5700),
      ),
      RouteStep(
        instruction: 'Arrive',
        maneuver: 'ARRIVE',
        distanceMeters: 50,
        end: GeoPoint(latitude: 23.0282, longitude: 72.5700),
      ),
    ];
    const GeoPoint atStart = GeoPoint(latitude: 23.0280, longitude: 72.5700);
    expect(
      metersBetween(atStart, steps[2].end),
      lessThan(metersBetween(atStart, steps[0].end)),
    );
    final GuidanceBanner? banner = guidanceBanner(
      steps: steps,
      position: atStart,
    );
    expect(banner!.stepIndex, 0);
    expect(banner.instruction, 'Head north');
  });

  test('SequentialGuidance keeps monotonic step index across samples', () {
    final List<RouteStep> steps = _lineSteps();
    final SequentialGuidance tracker = SequentialGuidance();

    final GuidanceBanner? first = tracker.update(
      steps: steps,
      position: GeoPoint(
        latitude: steps[0].end.latitude - 0.001,
        longitude: steps[0].end.longitude,
      ),
    );
    expect(first!.stepIndex, 0);

    final GuidanceBanner? second = tracker.update(
      steps: steps,
      position: steps[0].end,
    );
    expect(second!.stepIndex, 1);

    // GPS jitter back toward step 0 must not rewind the active maneuver.
    final GuidanceBanner? jitter = tracker.update(
      steps: steps,
      position: GeoPoint(
        latitude: steps[0].end.latitude - 0.0004,
        longitude: steps[0].end.longitude,
      ),
    );
    expect(jitter!.stepIndex, 1);
    expect(tracker.stepIndex, 1);
  });

  test('SequentialGuidance reset restarts progression for a new route', () {
    final List<RouteStep> steps = _lineSteps();
    final SequentialGuidance tracker = SequentialGuidance();

    tracker.update(steps: steps, position: steps[0].end);
    expect(tracker.stepIndex, 1);

    tracker.reset();
    expect(tracker.stepIndex, 0);

    final GuidanceBanner? afterReset = tracker.update(
      steps: steps,
      position: GeoPoint(
        latitude: steps[0].end.latitude - 0.001,
        longitude: steps[0].end.longitude,
      ),
    );
    expect(afterReset!.stepIndex, 0);
    expect(afterReset.instruction, 'Turn right onto CG Road');
  });

  test('SequentialGuidance repeated GPS ticks stay on the same maneuver', () {
    final List<RouteStep> steps = _lineSteps();
    final SequentialGuidance tracker = SequentialGuidance();
    final GeoPoint approaching = GeoPoint(
      latitude: steps[0].end.latitude - 0.0012,
      longitude: steps[0].end.longitude,
    );

    for (int i = 0; i < 5; i++) {
      final GuidanceBanner? banner = tracker.update(
        steps: steps,
        position: approaching,
      );
      expect(banner!.stepIndex, 0, reason: 'tick $i');
      expect(banner.speechKey, '0:Turn right onto CG Road');
    }

    expect(tracker.update(steps: steps, position: null)!.stepIndex, 0);
    expect(
      tracker.update(steps: const <RouteStep>[], position: approaching),
      isNull,
    );
    expect(tracker.stepIndex, 0);
  });

  test('off-route uses segment distance, not only vertices', () {
    const GeoPoint a = GeoPoint(latitude: 23.0300, longitude: 72.5700);
    const GeoPoint b = GeoPoint(latitude: 23.0320, longitude: 72.5700);
    final List<GeoPoint> sparse = <GeoPoint>[a, b];

    // Midpoint between sparse vertices — on the road chord.
    const GeoPoint onSegment = GeoPoint(latitude: 23.0310, longitude: 72.5700);
    expect(shouldRecalculateRoute(line: sparse, position: onSegment), isFalse);
    expect(
      distanceToPolylineMeters(line: sparse, position: onSegment),
      lessThan(20),
    );

    // ~200 m east of the segment — genuinely off route.
    const GeoPoint offRoute = GeoPoint(latitude: 23.0310, longitude: 72.5720);
    expect(shouldRecalculateRoute(line: sparse, position: offRoute), isTrue);
    expect(
      distanceToPolylineMeters(line: sparse, position: offRoute),
      greaterThan(80),
    );

    // Degenerate zero-length segment falls back to point distance.
    expect(
      distanceToSegmentMeters(position: onSegment, start: a, end: a),
      closeTo(metersBetween(onSegment, a), 1),
    );
    expect(
      shouldRecalculateRoute(line: <GeoPoint>[a], position: offRoute),
      isFalse,
    );
  });

  test('vehicle map marker assets follow category mapping', () {
    expect(
      vehicleMapMarkerAssetPath(vehicleMarkerFor('Bike')),
      'assets/customer/images/3d/idhar_udhar_delivery_bike.png',
    );
    expect(
      vehicleMapMarkerAssetPath(vehicleMarkerFor('Scooty')),
      'assets/rider/images/rider_delivery_scooter_3.png',
    );
    expect(
      vehicleMapMarkerAssetPath(vehicleMarkerFor('Truck')),
      'assets/customer/images/3d/idhar_udhar_delivery_truck_1.png',
    );
    expect(vehicleMapMarkerAssetPath(vehicleMarkerFor('Auto')), isNull);
    expect(vehicleMapMarkerAssetPath(vehicleMarkerFor('')), isNull);
  });
}

List<RouteStep> _lineSteps() {
  return const <RouteStep>[
    RouteStep(
      instruction: 'Turn right onto CG Road',
      maneuver: 'TURN_RIGHT',
      distanceMeters: 200,
      end: GeoPoint(latitude: 23.0300, longitude: 72.5700),
    ),
    RouteStep(
      instruction: 'Turn left onto Ashram Road',
      maneuver: 'TURN_LEFT',
      distanceMeters: 250,
      end: GeoPoint(latitude: 23.0320, longitude: 72.5700),
    ),
    RouteStep(
      instruction: 'You have arrived',
      maneuver: 'ARRIVE',
      distanceMeters: 100,
      end: GeoPoint(latitude: 23.0335, longitude: 72.5700),
    ),
  ];
}
