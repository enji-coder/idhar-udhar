import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/data/location/rider_presence_tick.dart';
import 'package:idhar_udhar/shared/maps/geo_point.dart';

void main() {
  test('prefers fresh GPS while Online', () {
    expect(
      riderPresenceTickAction(gpsOk: true, hasLastKnown: false),
      RiderPresenceTickAction.postFreshGps,
    );
  });

  test('temporary GPS failure reuses last known fix before heartbeat', () {
    expect(
      riderPresenceTickAction(gpsOk: false, hasLastKnown: true),
      RiderPresenceTickAction.repostLastKnown,
    );
  });

  test('heartbeat-only when GPS fails and no last known fix exists', () {
    expect(
      riderPresenceTickAction(gpsOk: false, hasLastKnown: false),
      RiderPresenceTickAction.heartbeatOnly,
    );
  });

  test('location foreground service waits for location permission', () {
    expect(riderLocationPermissionAllowsForegroundService(null), isTrue);
    expect(
      riderLocationPermissionAllowsForegroundService(
        LocationFailure.serviceDisabled,
      ),
      isTrue,
    );
    expect(
      riderLocationPermissionAllowsForegroundService(
        LocationFailure.unavailable,
      ),
      isTrue,
    );
    expect(
      riderLocationPermissionAllowsForegroundService(
        LocationFailure.permissionDenied,
      ),
      isFalse,
    );
    expect(
      riderLocationPermissionAllowsForegroundService(
        LocationFailure.permissionPermanentlyDenied,
      ),
      isFalse,
    );
  });
}
