import 'dart:math' as math;

/// Ordered delivery stop. Never store destinations as a comma-separated string.
class DeliveryStop {
  const DeliveryStop({
    required this.id,
    required this.sequence,
    required this.label,
    required this.address,
    this.city = '',
    this.latitude,
    this.longitude,
    this.kind = DeliveryStopKind.drop,
  });

  final String id;
  final int sequence;
  final String label;
  final String address;
  final String city;
  final double? latitude;
  final double? longitude;
  final DeliveryStopKind kind;
}

enum DeliveryStopKind { pickup, drop }

abstract final class GeoMath {
  static const double _earthKm = 6371;

  static double haversineKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final double dLat = _toRad(lat2 - lat1);
    final double dLng = _toRad(lng2 - lng1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthKm * c;
  }

  static double routeKm(List<DeliveryStop> orderedStops) {
    double total = 0;
    for (int i = 1; i < orderedStops.length; i++) {
      final DeliveryStop a = orderedStops[i - 1];
      final DeliveryStop b = orderedStops[i];
      if (a.latitude == null ||
          a.longitude == null ||
          b.latitude == null ||
          b.longitude == null) {
        continue;
      }
      total += haversineKm(
        lat1: a.latitude!,
        lng1: a.longitude!,
        lat2: b.latitude!,
        lng2: b.longitude!,
      );
    }
    return total;
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
