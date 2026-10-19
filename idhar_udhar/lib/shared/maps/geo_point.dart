class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      !(latitude == 0 && longitude == 0);
}

/// Stable key for a pickup/drop coordinate list. Same points do not change it.
String routePointKey(List<GeoPoint> points) {
  return points
      .map(
        (GeoPoint point) =>
            '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}',
      )
      .join('|');
}

class ResolvedAddress {
  const ResolvedAddress({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.city = '',
  });

  final double latitude;
  final double longitude;
  final String address;
  final String city;

  GeoPoint get point => GeoPoint(latitude: latitude, longitude: longitude);
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    this.secondaryText = '',
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;

  String get subtitle => secondaryText.trim();
}

class DisplayRoute {
  const DisplayRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<GeoPoint> points;
  final int distanceMeters;
  final int durationSeconds;

  double get distanceKm => distanceMeters / 1000.0;

  int get etaMinutes {
    if (durationSeconds <= 0) {
      return 0;
    }
    return (durationSeconds / 60).ceil();
  }

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get etaLabel {
    final int minutes = etaMinutes;
    if (minutes <= 0) {
      return '—';
    }
    if (minutes < 60) {
      return '$minutes min';
    }
    final int hours = minutes ~/ 60;
    final int rem = minutes % 60;
    if (rem == 0) {
      return '${hours}h';
    }
    return '${hours}h ${rem}m';
  }
}

enum LocationFailure {
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
  unavailable,
  timeout,
}

class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.bearingDegrees,
    this.speedMps,
    this.timeMillis,
    this.bearingAccuracyDegrees,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;

  /// Clockwise degrees from true north. This is GPS course-over-ground when
  /// the platform reports a bearing, not the phone compass.
  final double? bearingDegrees;

  /// Ground speed in meters per second, when the platform reports it.
  final double? speedMps;

  /// Location fix time in Unix epoch milliseconds, when the platform reports it.
  final int? timeMillis;

  /// Uncertainty of [bearingDegrees], in degrees, when the platform reports it.
  final double? bearingAccuracyDegrees;

  GeoPoint get point => GeoPoint(latitude: latitude, longitude: longitude);

  DateTime? get capturedAt {
    final int? millis = timeMillis;
    if (millis == null || millis <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
}

class LocationResult {
  const LocationResult._({this.location, this.failure});

  const LocationResult.ok(DeviceLocation location) : this._(location: location);

  const LocationResult.fail(LocationFailure failure) : this._(failure: failure);

  final DeviceLocation? location;
  final LocationFailure? failure;

  bool get isOk => location != null;
}

abstract final class MapsDefaults {
  /// Ahmedabad / Navrangpura — matches the existing mock catalog.
  static const GeoPoint cityCenter = GeoPoint(
    latitude: 23.0330,
    longitude: 72.5660,
  );
}
