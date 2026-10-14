import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/features/navigation/route_guidance.dart';
import 'package:idhar_udhar/rider/features/navigation/vehicle_marker.dart';
import 'package:idhar_udhar/rider/features/navigation/waiting_clock.dart';
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

  test('vehicle marker follows the order category and is not a car', () {
    expect(vehicleMarkerFor('Scooty'), RiderVehicleMarker.scooter);
    expect(vehicleMarkerFor('Bike'), RiderVehicleMarker.bike);
    expect(vehicleMarkerFor(''), RiderVehicleMarker.parcel);
    expect(vehicleMarkerIcon(RiderVehicleMarker.scooter), isNot(vehicleMarkerIcon(RiderVehicleMarker.truck)));
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
    expect(shouldSpeakCue(banner: first, lastSpokenKey: '1:Turn right'), isFalse);
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
}
