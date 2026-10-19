import 'dart:math' as math;

import 'package:idhar_udhar/shared/maps/geo_point.dart';

import 'route_guidance.dart';

/// Rider position and travel heading used by the navigation arrow.
class NavigationPose {
  const NavigationPose({
    required this.position,
    required this.headingDegrees,
  });

  final GeoPoint position;

  /// Clockwise degrees from true north. `0` is north.
  final double headingDegrees;
}

/// A fix older than this is not the rider's current position.
const Duration kNavigationFixMaxAge = Duration(seconds: 45);

/// While a fresher pose exists, a fix worse than this does not move the arrow.
const double kPoorFixAccuracyMeters = 80;

/// Accepted, but the UI must say the position is approximate.
const double kApproximateAccuracyMeters = 65;

enum NavigationFixQuality { accepted, approximate, held, stale }

/// Turns real GPS samples into a stable arrow pose.
///
/// Does not invent coordinates. A poor or jittery sample keeps the last
/// accepted fix, and heading changes only when GPS course or the rider's
/// actual movement supports them. Compass heading is not used.
class NavigationPoseTracker {
  NavigationPose? current;
  NavigationFixQuality lastQuality = NavigationFixQuality.held;
  double lastSpeedMps = 0;
  bool _headingFromTravel = false;
  DateTime? _acceptedAt;

  String? get fixNotice {
    switch (lastQuality) {
      case NavigationFixQuality.approximate:
        return 'GPS accuracy is limited. Position is approximate.';
      case NavigationFixQuality.stale:
        return 'GPS signal is stale. Waiting for a fresh location.';
      case NavigationFixQuality.accepted:
      case NavigationFixQuality.held:
        return null;
    }
  }

  NavigationPose? update(DeviceLocation sample, {DateTime? now}) {
    final DateTime clock = (now ?? DateTime.now()).toUtc();
    if (!_valid(sample.latitude, sample.longitude)) {
      return current;
    }
    final DateTime? captured = sample.capturedAt?.toUtc();
    if (_isUnusableTimestamp(captured, clock)) {
      lastQuality = NavigationFixQuality.stale;
      return current;
    }
    final GeoPoint next = GeoPoint(
      latitude: sample.latitude,
      longitude: sample.longitude,
    );
    final NavigationPose? previous = current;
    final double? accuracy = _finite(sample.accuracy);
    final bool previousFresh = _acceptedAt != null &&
        clock.difference(_acceptedAt!) <= kNavigationFixMaxAge;
    if (previous != null &&
        previousFresh &&
        accuracy != null &&
        accuracy > kPoorFixAccuracyMeters) {
      lastQuality = NavigationFixQuality.held;
      return previous;
    }
    final double moved =
        previous == null ? 0 : metersBetween(previous.position, next);
    final double jitter =
        accuracy == null ? 3 : math.min(12, math.max(3, accuracy * 0.35));
    if (previous != null && moved < jitter) {
      _applyHeading(
        sample: sample,
        from: previous.position,
        to: next,
        moved: moved,
      );
      final double? speed = _finite(sample.speedMps);
      if (speed != null) {
        lastSpeedMps = speed;
      }
      _markAccepted(captured ?? clock, accuracy);
      return current;
    }
    _applyHeading(
      sample: sample,
      from: previous?.position,
      to: next,
      moved: moved,
    );
    lastSpeedMps = _finite(sample.speedMps) ?? lastSpeedMps;
    current = NavigationPose(
      position: next,
      headingDegrees: current?.headingDegrees ?? 0,
    );
    _markAccepted(captured ?? clock, accuracy);
    return current;
  }

  /// Points the arrow along the real route until travel heading exists.
  void alignToRoute(List<GeoPoint> line) {
    final NavigationPose? pose = current;
    if (_headingFromTravel || pose == null) {
      return;
    }
    final double? course = bearingAlongRoute(pose.position, line);
    if (course == null) {
      return;
    }
    current = NavigationPose(
      position: pose.position,
      headingDegrees: course,
    );
  }

  void _markAccepted(DateTime at, double? accuracy) {
    _acceptedAt = at;
    lastQuality = accuracy != null && accuracy > kApproximateAccuracyMeters
        ? NavigationFixQuality.approximate
        : NavigationFixQuality.accepted;
  }

  bool _isUnusableTimestamp(DateTime? captured, DateTime clock) {
    if (captured == null) {
      return false;
    }
    final Duration age = clock.difference(captured);
    if (age < const Duration(minutes: -2)) {
      return true;
    }
    return age > kNavigationFixMaxAge;
  }

  void _applyHeading({
    required DeviceLocation sample,
    required GeoPoint? from,
    required GeoPoint to,
    required double moved,
  }) {
    final double? platform = _platformBearing(sample, moved);
    if (platform != null) {
      final double heading = _blendHeading(platform);
      _headingFromTravel = true;
      current = NavigationPose(
        position: current?.position ?? to,
        headingDegrees: heading,
      );
      return;
    }
    if (from != null && moved >= 8) {
      final double heading = _blendHeading(bearingDegrees(from, to));
      _headingFromTravel = true;
      current = NavigationPose(
        position: current?.position ?? to,
        headingDegrees: heading,
      );
    }
  }

  /// Keeps small course noise from spinning the arrow, and applies a real
  /// turn immediately so guidance does not lag behind the rider.
  double _blendHeading(double next) {
    final double target = normalizeHeading(next);
    final double? previous = current?.headingDegrees;
    if (!_headingFromTravel || previous == null) {
      return target;
    }
    final double delta = _shortestDelta(previous, target);
    if (delta.abs() < 3) {
      return previous;
    }
    if (delta.abs() >= 28) {
      return target;
    }
    return normalizeHeading(previous + delta * 0.5);
  }

  double _shortestDelta(double from, double to) {
    double delta = normalizeHeading(to) - normalizeHeading(from);
    if (delta > 180) {
      delta -= 360;
    } else if (delta < -180) {
      delta += 360;
    }
    return delta;
  }

  double? _platformBearing(DeviceLocation sample, double moved) {
    final double? bearingAccuracy = _finite(sample.bearingAccuracyDegrees);
    if (bearingAccuracy != null && bearingAccuracy > 40) {
      return null;
    }
    final double? bearing = _finite(sample.bearingDegrees);
    if (bearing == null) {
      return null;
    }
    final double? speed = _finite(sample.speedMps);
    final bool moving = (speed != null && speed >= 1) || moved >= 8;
    if (!moving) {
      return null;
    }
    return normalizeHeading(bearing);
  }

  bool _valid(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude.abs() <= 90 &&
        longitude.abs() <= 180;
  }

  double? _finite(double? value) {
    if (value == null || !value.isFinite) {
      return null;
    }
    return value;
  }
}

/// Clockwise bearing from [from] to [to], in degrees from true north.
double bearingDegrees(GeoPoint from, GeoPoint to) {
  final double lat1 = from.latitude * math.pi / 180;
  final double lat2 = to.latitude * math.pi / 180;
  final double dLng = (to.longitude - from.longitude) * math.pi / 180;
  final double y = math.sin(dLng) * math.cos(lat2);
  final double x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return normalizeHeading(math.atan2(y, x) * 180 / math.pi);
}

double normalizeHeading(double degrees) {
  final double wrapped = degrees % 360;
  return wrapped < 0 ? wrapped + 360 : wrapped;
}

/// Forward bearing of the route segment nearest [position], when it is close.
double? bearingAlongRoute(GeoPoint position, List<GeoPoint> line) {
  if (line.length < 2) {
    return null;
  }
  double nearest = double.infinity;
  double? bearing;
  for (int i = 0; i < line.length - 1; i++) {
    final double distance = distanceToSegmentMeters(
      position: position,
      start: line[i],
      end: line[i + 1],
    );
    if (distance < nearest) {
      nearest = distance;
      bearing = bearingDegrees(line[i], line[i + 1]);
    }
  }
  if (nearest > 40) {
    return null;
  }
  return bearing;
}
