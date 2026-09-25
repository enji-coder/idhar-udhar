import 'geo_point.dart';
import 'google_maps_http.dart';
import 'maps_runtime.dart';
import 'polyline_codec.dart';

/// Routes API for map polylines / ETA display. Does not affect fare calculation.
class RoutesService {
  RoutesService(this._http);

  static const String _url =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const String _fieldMask =
      'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline';

  final GoogleMapsHttp _http;
  String? _cacheKey;
  DisplayRoute? _cache;

  Future<DisplayRoute?> compute({
    required GeoPoint origin,
    required GeoPoint destination,
    List<GeoPoint> intermediates = const <GeoPoint>[],
  }) async {
    if (MapsRuntime.isFlutterTest) {
      return null;
    }
    final String key = _key(origin, destination, intermediates);
    if (_cacheKey == key) {
      return _cache;
    }
    final Map<String, Object?> body = <String, Object?>{
      'origin': _waypoint(origin),
      'destination': _waypoint(destination),
      if (intermediates.isNotEmpty)
        'intermediates':
            intermediates.map(_waypoint).toList(growable: false),
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_UNAWARE',
      'computeAlternativeRoutes': false,
      'polylineQuality': 'OVERVIEW',
    };
    final response = await _http.post(
      url: _url,
      data: body,
      fieldMask: _fieldMask,
    );
    final Object? data = response?.data;
    if (data is! Map) {
      return null;
    }
    final DisplayRoute? parsed = parseRoute(data);
    if (parsed != null) {
      _cacheKey = key;
      _cache = parsed;
    }
    return parsed;
  }

  static DisplayRoute? parseRoute(Map<dynamic, dynamic> json) {
    final Object? routes = json['routes'];
    if (routes is! List || routes.isEmpty) {
      return null;
    }
    final Object? route = routes.first;
    if (route is! Map) {
      return null;
    }
    final int? meters = (route['distanceMeters'] as num?)?.round();
    final int seconds = _durationSeconds(route['duration']);
    if (meters == null || meters <= 0 || seconds < 0) {
      return null;
    }
    final Object? polyline = route['polyline'];
    String encoded = '';
    if (polyline is Map) {
      encoded = '${polyline['encodedPolyline'] ?? ''}';
    }
    final List<GeoPoint> points = PolylineCodec.decode(encoded);
    if (points.length < 2) {
      return null;
    }
    return DisplayRoute(
      points: points,
      distanceMeters: meters,
      durationSeconds: seconds,
    );
  }

  static int _durationSeconds(Object? value) {
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      final Match? match = RegExp(r'^(\d+)(?:\.\d+)?s$').firstMatch(value.trim());
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    }
    return -1;
  }

  static Map<String, Object?> _waypoint(GeoPoint point) {
    return <String, Object?>{
      'location': <String, Object?>{
        'latLng': <String, Object?>{
          'latitude': point.latitude,
          'longitude': point.longitude,
        },
      },
    };
  }

  static String _key(
    GeoPoint origin,
    GeoPoint destination,
    List<GeoPoint> intermediates,
  ) {
    final StringBuffer buffer = StringBuffer()
      ..write(_round(origin.latitude))
      ..write(',')
      ..write(_round(origin.longitude))
      ..write('>')
      ..write(_round(destination.latitude))
      ..write(',')
      ..write(_round(destination.longitude));
    for (final GeoPoint point in intermediates) {
      buffer
        ..write('|')
        ..write(_round(point.latitude))
        ..write(',')
        ..write(_round(point.longitude));
    }
    return buffer.toString();
  }

  static String _round(double value) => value.toStringAsFixed(5);
}
