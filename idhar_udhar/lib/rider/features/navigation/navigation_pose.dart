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

/// Turns real GPS samples into a stable arrow pose.
///
/// Does not invent coordinates. A poor or jittery sample keeps the last
/// accepted fix, and heading changes only when the platform bearing or the
/// rider's actual movement supports them.
class NavigationPoseTracker {
  NavigationPose? current;
  bool _headingFromTravel = false;

  NavigationPose? update(DeviceLocation sample) {
    if (!_valid(sample.latitude, sample.longitude)) {
      return current;
    }
    final GeoPoint next = GeoPoint(
      latitude: sample.latitude,
      longitude: sample.longitude,
    );
    final NavigationPose? previous = current;
    final double? accuracy = _finite(sample.accuracy);
    if (previous != null && accuracy != null && accuracy > 80) {
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
      return current;
    }
    _applyHeading(
      sample: sample,
      from: previous?.position,
      to: next,
      moved: moved,
    );
    current = NavigationPose(
      position: next,
      headingDegrees: current?.headingDegrees ?? 0,
    );
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

  void _applyHeading({
    required DeviceLocation sample,
    required GeoPoint? from,
    required GeoPoint to,
    required double moved,
  }) {
    final double? platform = _platformBearing(sample, moved);
    if (platform != null) {
      _headingFromTravel = true;
      current = NavigationPose(
        position: current?.position ?? to,
        headingDegrees: platform,
      );
      return;
    }
    if (from != null && moved >= 8) {
      _headingFromTravel = true;
      current = NavigationPose(
        position: current?.position ?? to,
        headingDegrees: bearingDegrees(from, to),
      );
    }
  }

  double? _platformBearing(DeviceLocation sample, double moved) {
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
