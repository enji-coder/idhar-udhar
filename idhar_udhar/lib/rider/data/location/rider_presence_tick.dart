import 'package:idhar_udhar/shared/maps/geo_point.dart';

/// Decides what an Online presence tick should do when GPS may have failed.
///
/// Used by [RiderLocationPublisher] (foreground Dart timer) and documented for
/// the native foreground service, which follows the same order.
enum RiderPresenceTickAction {
  postFreshGps,
  repostLastKnown,
  heartbeatOnly,
}

RiderPresenceTickAction riderPresenceTickAction({
  required bool gpsOk,
  required bool hasLastKnown,
}) {
  if (gpsOk) {
    return RiderPresenceTickAction.postFreshGps;
  }
  if (hasLastKnown) {
    return RiderPresenceTickAction.repostLastKnown;
  }
  return RiderPresenceTickAction.heartbeatOnly;
}

/// Android 14+ rejects a location foreground service until location permission
/// is granted. GPS being off or a transient read failure is not that case.
bool riderLocationPermissionAllowsForegroundService(LocationFailure? failure) {
  return failure != LocationFailure.permissionDenied &&
      failure != LocationFailure.permissionPermanentlyDenied;
}
