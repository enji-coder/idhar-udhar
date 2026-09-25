import 'geo_point.dart';

/// Decodes a Google encoded polyline (precision 5) for map display only.
abstract final class PolylineCodec {
  static List<GeoPoint> decode(String encoded, {int precision = 5}) {
    if (encoded.isEmpty) {
      return const <GeoPoint>[];
    }
    final double factor = _pow10(precision);
    final List<GeoPoint> points = <GeoPoint>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    int nextDelta() {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        if (index >= encoded.length) {
          return 0;
        }
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final bool negative = (result & 1) == 1;
      final int magnitude = result >> 1;
      return negative ? ~magnitude : magnitude;
    }

    while (index < encoded.length) {
      lat += nextDelta();
      lng += nextDelta();
      points.add(
        GeoPoint(
          latitude: lat / factor,
          longitude: lng / factor,
        ),
      );
    }
    return points;
  }

  static double _pow10(int precision) {
    double value = 1;
    for (int i = 0; i < precision; i++) {
      value *= 10;
    }
    return value;
  }
}
