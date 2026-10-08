/// Display distance. Under 1 km uses meters. At 1 km and above uses kilometers.
/// This is formatting only. It is not a dispatch radius.
String formatTripDistanceKm(double kilometers) {
  if (!kilometers.isFinite || kilometers <= 0) {
    return '—';
  }
  final int meters = (kilometers * 1000).round();
  if (meters < 1000) {
    return '$meters m';
  }
  final double km = meters / 1000;
  return '${km.toStringAsFixed(1)} km';
}

/// Same 30 km/h planning speed as the backend offer ETA.
/// Used only when the offer payload omitted duration but included distance.
int plannedTripMinutes(double kilometers) {
  if (!kilometers.isFinite || kilometers <= 0) {
    return 0;
  }
  final int seconds = (kilometers * 1000 / (30000 / 3600)).round();
  if (seconds <= 0) {
    return 0;
  }
  return (seconds / 60).ceil();
}
