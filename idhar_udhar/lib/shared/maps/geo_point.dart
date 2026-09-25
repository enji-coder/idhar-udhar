class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.abs() <= 90 && longitude.abs() <= 180 &&
      !(latitude == 0 && longitude == 0);
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

  GeoPoint get point =>
      GeoPoint(latitude: latitude, longitude: longitude);
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
  });

  final double latitude;
  final double longitude;
  final double? accuracy;

  GeoPoint get point =>
      GeoPoint(latitude: latitude, longitude: longitude);
}

class LocationResult {
  const LocationResult._({this.location, this.failure});

  const LocationResult.ok(DeviceLocation location)
      : this._(location: location);

  const LocationResult.fail(LocationFailure failure)
      : this._(failure: failure);

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
