import 'dart:math' as math;

import 'package:idhar_udhar/shared/maps/maps.dart';

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

GuidanceBanner? guidanceBanner({
  required List<RouteStep> steps,
  required GeoPoint? position,
}) {
  if (steps.isEmpty) {
    return null;
  }
  if (position == null) {
    final RouteStep first = steps.first;
    return GuidanceBanner(
      instruction: first.instruction,
      distanceLabel: formatMeters(first.distanceMeters),
      meters: first.distanceMeters,
      stepIndex: 0,
      speechKey: '0:${first.instruction}',
    );
  }
  int nearest = 0;
  double nearestMeters = double.infinity;
  for (int index = 0; index < steps.length; index++) {
    final double distance = metersBetween(position, steps[index].end);
    if (distance < nearestMeters) {
      nearestMeters = distance;
      nearest = index;
    }
  }
  int index = nearest;
  if (nearestMeters < 35 && nearest + 1 < steps.length) {
    index = nearest + 1;
  }
  final RouteStep step = steps[index];
  final int meters = index == nearest
      ? nearestMeters.round()
      : metersBetween(position, step.end).round();
  return GuidanceBanner(
    instruction: step.instruction,
    distanceLabel: formatMeters(meters),
    meters: meters,
    stepIndex: index,
    speechKey: '$index:${step.instruction}',
  );
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
bool shouldRecalculateRoute({
  required List<GeoPoint> line,
  required GeoPoint position,
}) {
  if (line.length < 2) {
    return false;
  }
  double nearest = double.infinity;
  for (final GeoPoint point in line) {
    final double distance = metersBetween(position, point);
    if (distance < nearest) {
      nearest = distance;
    }
  }
  return nearest > 80;
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
