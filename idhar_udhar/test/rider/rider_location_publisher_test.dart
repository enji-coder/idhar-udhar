import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/data/location/rider_presence_tick.dart';

/// Publisher behavior is covered via [riderPresenceTickAction] so we do not
/// need Dio/secure-storage fakes here. Native FGS start/stop is Android-only.
void main() {
  test('Online presence tick policy stays ordered for background gaps', () {
    expect(
      [
        riderPresenceTickAction(gpsOk: true, hasLastKnown: true),
        riderPresenceTickAction(gpsOk: false, hasLastKnown: true),
        riderPresenceTickAction(gpsOk: false, hasLastKnown: false),
      ],
      <RiderPresenceTickAction>[
        RiderPresenceTickAction.postFreshGps,
        RiderPresenceTickAction.repostLastKnown,
        RiderPresenceTickAction.heartbeatOnly,
      ],
    );
  });
}
