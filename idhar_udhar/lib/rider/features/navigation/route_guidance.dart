import 'dart:math' as math;

import 'package:idhar_udhar/shared/maps/maps.dart';

/// Distance at which the rider is treated as having reached a maneuver end.
const double kManeuverArriveMeters = 35;

class GuidanceBanner {
  const GuidanceBanner({
    required this.instruction,
    required this.distanceLabel,
    required this.meters,
    required this.stepIndex,
    required this.speechKey,
  });

  final String instruction;
  final String distanceLabel;
  final int meters;
  final int stepIndex;
  final String speechKey;
}

/// Holds the active step across GPS samples so progression stays monotonic.
///
/// Owned by [ActiveDeliveryScreen] for the active trip. Call [reset] when the
/// order, destination, or computed step list changes — not on every GPS tick.
class SequentialGuidance {
  int stepIndex = 0;

  GuidanceBanner? update({
    required List<RouteStep> steps,
    required GeoPoint? position,
  }) {
    if (steps.isEmpty) {
      return null;
    }
    final GuidanceBanner? banner = guidanceBanner(
      steps: steps,
      position: position,
      fromStepIndex: stepIndex.clamp(0, steps.length - 1),
    );
    if (banner != null) {
      stepIndex = banner.stepIndex;
    }
    return banner;
  }

  void reset() => stepIndex = 0;
}

/// Picks the active turn by walking steps in order from [fromStepIndex].
///
/// Advances when the rider reaches the current end ([kManeuverArriveMeters])
/// or has moved past that end toward the next step. Does not jump to a later
/// step merely because that endpoint is the geographic nearest neighbor.
GuidanceBanner? guidanceBanner({
  required List<RouteStep> steps,
  required GeoPoint? position,
  int fromStepIndex = 0,
}) {
  if (steps.isEmpty) {
    return null;
  }
  if (position == null) {
    final int index = fromStepIndex.clamp(0, steps.length - 1);
    final RouteStep step = steps[index];
    return GuidanceBanner(
      instruction: step.instruction,
      distanceLabel: formatMeters(step.distanceMeters),
      meters: step.distanceMeters,
      stepIndex: index,
      speechKey: '$index:${step.instruction}',
    );
  }
  final int index = activeStepIndex(
    steps: steps,
    position: position,
    fromStepIndex: fromStepIndex,
  );
  final RouteStep step = steps[index];
  final int meters = metersBetween(position, step.end).round();
  return GuidanceBanner(
    instruction: step.instruction,
    distanceLabel: formatMeters(meters),
    meters: meters,
    stepIndex: index,
    speechKey: '$index:${step.instruction}',
  );
}

/// Ordered step index for [position], never below [fromStepIndex].
int activeStepIndex({
  required List<RouteStep> steps,
  required GeoPoint position,
  int fromStepIndex = 0,
}) {
  if (steps.isEmpty) {
    return 0;
  }
  int index = fromStepIndex.clamp(0, steps.length - 1);
  while (index < steps.length - 1) {
    final GeoPoint currentEnd = steps[index].end;
    final double toCurrent = metersBetween(position, currentEnd);
    if (toCurrent <= kManeuverArriveMeters) {
      index++;
      continue;
    }
    final GeoPoint nextEnd = steps[index + 1].end;
    if (_isPastTowardNext(position, currentEnd, nextEnd)) {
      index++;
      continue;
    }
    break;
  }
  return index;
}

/// True when [position] lies on the far side of [currentEnd] along the leg
/// toward [nextEnd] (consecutive steps only — no skip to distant endpoints).
bool _isPastTowardNext(
  GeoPoint position,
  GeoPoint currentEnd,
  GeoPoint nextEnd,
) {
  final double vx = nextEnd.latitude - currentEnd.latitude;
  final double vy = nextEnd.longitude - currentEnd.longitude;
  final double wx = position.latitude - currentEnd.latitude;
  final double wy = position.longitude - currentEnd.longitude;
  return vx * wx + vy * wy > 0;
}

/// Speak the first instruction once, then each later turn once inside 200 m.
bool shouldSpeakCue({
  required GuidanceBanner banner,
  required String? lastSpokenKey,
}) {
  if (banner.speechKey == lastSpokenKey) {
    return false;
  }
  if (banner.stepIndex == 0 && lastSpokenKey == null) {
    return true;
  }
  return banner.meters <= 200;
}

/// Recalculate after the rider is meaningfully off the drawn road path.
///
/// Uses distance to polyline **segments** (not only vertices) so sparse
/// OVERVIEW/HIGH_QUALITY polylines do not false-trigger between corners.
bool shouldRecalculateRoute({
  required List<GeoPoint> line,
  required GeoPoint position,
  double thresholdMeters = 80,
}) {
  if (line.length < 2) {
    return false;
  }
  return distanceToPolylineMeters(line: line, position: position) >
      thresholdMeters;
}

/// Shortest distance from [position] to any segment of [line].
double distanceToPolylineMeters({
  required List<GeoPoint> line,
  required GeoPoint position,
}) {
  if (line.isEmpty) {
    return double.infinity;
  }
  if (line.length == 1) {
    return metersBetween(position, line.first);
  }
  double nearest = double.infinity;
  for (int i = 0; i < line.length - 1; i++) {
    final double distance = distanceToSegmentMeters(
      position: position,
      start: line[i],
      end: line[i + 1],
    );
    if (distance < nearest) {
      nearest = distance;
    }
  }
  return nearest;
}

/// Distance from [position] to the great-circle chord approximated in local
/// meters via equirectangular projection around [start].
double distanceToSegmentMeters({
  required GeoPoint position,
  required GeoPoint start,
  required GeoPoint end,
}) {
  final double lat0 = _rad(start.latitude);
  final double cosLat = math.cos(lat0).abs().clamp(1e-6, 1.0);
  const double ax = 0.0;
  const double ay = 0.0;
  final double bx =
      (_rad(end.longitude) - _rad(start.longitude)) * cosLat * 6371000;
  final double by = (_rad(end.latitude) - _rad(start.latitude)) * 6371000;
  final double px =
      (_rad(position.longitude) - _rad(start.longitude)) * cosLat * 6371000;
  final double py =
      (_rad(position.latitude) - _rad(start.latitude)) * 6371000;
  final double ab2 = bx * bx + by * by;
  if (ab2 < 1e-6) {
    return metersBetween(position, start);
  }
  double t = (px * bx + py * by) / ab2;
  if (t < 0) {
    t = 0;
  } else if (t > 1) {
    t = 1;
  }
  final double qx = ax + t * bx;
  final double qy = ay + t * by;
  final double dx = px - qx;
  final double dy = py - qy;
  return math.sqrt(dx * dx + dy * dy);
}

String formatMeters(int meters) {
  final int safe = meters < 0 ? 0 : meters;
  if (safe < 1000) {
    return '$safe m';
  }
  final double km = safe / 1000;
  return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
}

double metersBetween(GeoPoint a, GeoPoint b) {
  const double earth = 6371000;
  final double dLat = _rad(b.latitude - a.latitude);
  final double dLng = _rad(b.longitude - a.longitude);
  final double lat1 = _rad(a.latitude);
  final double lat2 = _rad(b.latitude);
  final double h = math.pow(math.sin(dLat / 2), 2).toDouble() +
      math.cos(lat1) *
          math.cos(lat2) *
          math.pow(math.sin(dLng / 2), 2).toDouble();
  return 2 * earth * math.asin(math.min(1, math.sqrt(h)));
}

double _rad(double degrees) => degrees * math.pi / 180;
