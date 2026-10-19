/// Pauses heading-up follow when the rider moves the map.
///
/// google_maps_flutter 2.18 reports [onCameraMoveStarted] with no reason.
/// The Android plugin receives the native reason and discards it. This gate
/// keeps at most one unmatched app start. The next start consumes it. Any
/// later start is a manual pan or compass tap.
///
/// A start before the first [onCameraIdle] is not treated as a gesture. The
/// callback cannot separate that gesture from the map's opening camera, so
/// follow stays on until a start arrives after the first idle.
class NavigationFollowGate {
  bool paused = false;
  bool settled = false;
  bool _expectAppStart = false;

  bool get hasPendingAppStart => _expectAppStart;

  /// Call immediately before this app's animateCamera.
  ///
  /// A second call does not add another token. Stacked animations would
  /// leave a start that never arrives and hide a later pan or compass tap.
  bool beginAppMove() {
    if (_expectAppStart) {
      return false;
    }
    _expectAppStart = true;
    return true;
  }

  /// The app move was not sent. Drops the unpaired start so a later gesture
  /// is not ignored.
  void cancelAppMove() {
    _expectAppStart = false;
  }

  /// True when this start paused follow.
  ///
  /// A pending app start is consumed even when [followEnabled] is false, so
  /// turning follow back on does not hide the next pan or compass tap.
  bool onPlatformMoveStarted({bool followEnabled = true}) {
    if (_expectAppStart) {
      _expectAppStart = false;
      return false;
    }
    if (!settled || paused || !followEnabled) {
      return false;
    }
    paused = true;
    return true;
  }

  /// The camera stopped. Does not drop an app start that has not arrived yet.
  void onCameraIdle() {
    settled = true;
  }

  void resume() {
    paused = false;
  }
}

/// One navigation-mode camera animation at a time.
///
/// [GoogleMapController.animateCamera] completes when the platform accepts
/// the update, not when the camera goes idle. The episode stays open until
/// its start has been seen and a later [onIdle] runs.
class NavigationCameraEpisode {
  final NavigationFollowGate follow = NavigationFollowGate();
  bool inFlight = false;
  bool startSeen = false;
  bool queued = false;

  /// True when the caller should invoke animateCamera now.
  bool requestAppMove() {
    if (follow.paused || inFlight) {
      return false;
    }
    if (!follow.beginAppMove()) {
      return false;
    }
    inFlight = true;
    startSeen = false;
    queued = false;
    return true;
  }

  /// Keep the newest GPS target without starting a second animation.
  void queueLatest() {
    if (inFlight) {
      queued = true;
    }
  }

  bool takeQueue() {
    if (!queued) {
      return false;
    }
    queued = false;
    return true;
  }

  void failAppMove() {
    follow.cancelAppMove();
    inFlight = false;
    startSeen = false;
  }

  /// True when this start paused follow.
  bool onMoveStarted({required bool followEnabled}) {
    final bool pausedNow =
        follow.onPlatformMoveStarted(followEnabled: followEnabled);
    if (inFlight && !follow.hasPendingAppStart) {
      startSeen = true;
    }
    return pausedNow;
  }

  /// True when the animation has finished and a newer target should be applied.
  ///
  /// An idle before the matching start belongs to the previous camera and
  /// leaves the episode open. The queued target is dropped when follow is
  /// off or paused.
  bool onIdle({required bool followEnabled}) {
    follow.onCameraIdle();
    if (!inFlight || !startSeen) {
      return false;
    }
    inFlight = false;
    startSeen = false;
    final bool apply = queued && followEnabled && !follow.paused;
    queued = false;
    return apply;
  }
}

/// Camera values the Maps SDK can apply during in-app navigation.
abstract final class NavigationCamera {
  static const double zoom = 17.5;
  static const double movingTilt = 48;

  static double tiltForSpeed(double speedMps) =>
      speedMps >= 1.2 ? movingTilt : 0;

  /// Five-degree buckets so tiny GPS heading noise does not restart the camera.
  static int bearingBucket(double bearing) {
    final double wrapped = bearing % 360;
    final double positive = wrapped < 0 ? wrapped + 360 : wrapped;
    return (positive / 5).round() % 72;
  }
}
