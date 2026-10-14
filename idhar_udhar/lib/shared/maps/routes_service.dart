import 'package:flutter/foundation.dart';

import 'geo_point.dart';
import 'google_maps_http.dart';
import 'maps_runtime.dart';
import 'polyline_codec.dart';

/// Routes API for the pickup-to-drop polyline, distance, and travel time.
/// The customer booking draft stores that distance for the fare estimate.
class RoutesService {
  RoutesService(this._http);

  static const String _url =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const String _fieldMask =
      'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline';
  static const String _guidanceFieldMask =
      'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps.distanceMeters,routes.legs.steps.navigationInstruction,routes.legs.steps.endLocation.latLng';

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

  /// Road route plus turn steps. Customer fare quotes keep [compute].
  Future<RouteGuidanceResult> computeGuidance({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    final MapsHttpOutcome outcome = await _http.postOutcome(
      url: _url,
      data: <String, Object?>{
        'origin': _waypoint(origin),
        'destination': _waypoint(destination),
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_UNAWARE',
        'computeAlternativeRoutes': false,
        'polylineQuality': 'OVERVIEW',
      },
      fieldMask: _guidanceFieldMask,
    );
    final RouteGuidanceResult result = interpretGuidance(outcome);
    _logGuidance(result, origin, destination);
    return result;
  }

  static RouteGuidanceResult interpretGuidance(MapsHttpOutcome outcome) {
    if (outcome.failure == MapsHttpFailure.missingConfig) {
      return const RouteGuidanceResult(kind: RouteGuidanceKind.missingConfig);
    }
    if (outcome.failure == MapsHttpFailure.http ||
        outcome.failure == MapsHttpFailure.transport) {
      return RouteGuidanceResult(
        kind: RouteGuidanceKind.httpRejected,
        httpStatus: outcome.statusCode,
        errorStatus: outcome.errorStatus,
      );
    }
    final Object? data = outcome.data;
    if (data is! Map) {
      return RouteGuidanceResult(
        kind: RouteGuidanceKind.malformed,
        httpStatus: outcome.statusCode,
      );
    }
    final Object? routes = data['routes'];
    if (routes is! List || routes.isEmpty) {
      return RouteGuidanceResult(
        kind: RouteGuidanceKind.noRoute,
        httpStatus: outcome.statusCode,
        errorStatus: outcome.errorStatus,
      );
    }
    final GuidedRoute? guided = parseGuidance(data, allowZeroDistance: true);
    if (guided == null) {
      return RouteGuidanceResult(
        kind: RouteGuidanceKind.malformed,
        httpStatus: outcome.statusCode,
      );
    }
    return RouteGuidanceResult(
      kind: RouteGuidanceKind.success,
      route: guided,
      httpStatus: outcome.statusCode,
      distanceMeters: guided.route.distanceMeters,
      pointCount: guided.route.points.length,
    );
  }

  static void _logGuidance(
    RouteGuidanceResult result,
    GeoPoint origin,
    GeoPoint destination,
  ) {
    debugPrint(
      'RIDER_ROUTE kind=${result.kind.name} '
      'http=${result.httpStatus ?? '-'} '
      'error=${result.errorStatus ?? '-'} '
      'origin=${origin.latitude.toStringAsFixed(3)},${origin.longitude.toStringAsFixed(3)} '
      'dest=${destination.latitude.toStringAsFixed(3)},${destination.longitude.toStringAsFixed(3)} '
      'meters=${result.distanceMeters ?? '-'} '
      'points=${result.pointCount ?? '-'}',
    );
  }

  static GuidedRoute? parseGuidance(
    Map<dynamic, dynamic> json, {
    bool allowZeroDistance = false,
  }) {
    final DisplayRoute? route = parseRoute(
      json,
      allowZeroDistance: allowZeroDistance,
    );
    if (route == null) {
      return null;
    }
    final Object? routes = json['routes'];
    final Object? first = routes is List && routes.isNotEmpty ? routes.first : null;
    final List<RouteStep> steps = <RouteStep>[];
    if (first is Map) {
      final Object? legs = first['legs'];
      if (legs is List) {
        for (final Object? leg in legs) {
          if (leg is! Map) {
            continue;
          }
          final Object? rawSteps = leg['steps'];
          if (rawSteps is! List) {
            continue;
          }
          for (final Object? raw in rawSteps) {
            final RouteStep? step = _step(raw);
            if (step != null) {
              steps.add(step);
            }
          }
        }
      }
    }
    return GuidedRoute(route: route, steps: steps);
  }

  static RouteStep? _step(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Object? end = raw['endLocation'];
    GeoPoint? point;
    if (end is Map) {
      final Object? latLng = end['latLng'];
      if (latLng is Map) {
        final double? latitude = (latLng['latitude'] as num?)?.toDouble();
        final double? longitude = (latLng['longitude'] as num?)?.toDouble();
        if (latitude != null && longitude != null) {
          point = GeoPoint(latitude: latitude, longitude: longitude);
        }
      }
    }
    if (point == null) {
      return null;
    }
    final Object? instruction = raw['navigationInstruction'];
    String text = '';
    String maneuver = '';
    if (instruction is Map) {
      text = '${instruction['instructions'] ?? ''}'.trim();
      maneuver = '${instruction['maneuver'] ?? ''}'.trim();
    }
    if (text.isEmpty) {
      text = maneuverLabel(maneuver);
    }
    if (text.isEmpty) {
      return null;
    }
    return RouteStep(
      instruction: text,
      maneuver: maneuver,
      distanceMeters: (raw['distanceMeters'] as num?)?.round() ?? 0,
      end: point,
    );
  }

  static DisplayRoute? parseRoute(
    Map<dynamic, dynamic> json, {
    bool allowZeroDistance = false,
  }) {
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
    if (meters == null || meters < 0 || seconds < 0) {
      return null;
    }
    if (meters == 0 && !allowZeroDistance) {
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

class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.end,
  });

  final String instruction;
  final String maneuver;
  final int distanceMeters;
  final GeoPoint end;
}

class GuidedRoute {
  const GuidedRoute({
    required this.route,
    required this.steps,
  });

  final DisplayRoute route;
  final List<RouteStep> steps;
}

enum RouteGuidanceKind {
  success,
  missingConfig,
  httpRejected,
  noRoute,
  malformed,
}

class RouteGuidanceResult {
  const RouteGuidanceResult({
    required this.kind,
    this.route,
    this.httpStatus,
    this.errorStatus,
    this.distanceMeters,
    this.pointCount,
  });

  final RouteGuidanceKind kind;
  final GuidedRoute? route;
  final int? httpStatus;
  final String? errorStatus;
  final int? distanceMeters;
  final int? pointCount;
}

String routeGuidanceMessage(RouteGuidanceKind kind) {
  switch (kind) {
    case RouteGuidanceKind.success:
      return '';
    case RouteGuidanceKind.missingConfig:
      return 'Road navigation is unavailable on this device. The stop is still shown.';
    case RouteGuidanceKind.httpRejected:
      return 'The road service could not provide a route. The stop is still shown.';
    case RouteGuidanceKind.noRoute:
      return 'No road route was found. The stop is still shown.';
    case RouteGuidanceKind.malformed:
      return 'The road route could not be read. The stop is still shown.';
  }
}

String maneuverLabel(String maneuver) {
  switch (maneuver) {
    case 'TURN_LEFT':
      return 'Turn left';
    case 'TURN_RIGHT':
      return 'Turn right';
    case 'TURN_SLIGHT_LEFT':
      return 'Bear left';
    case 'TURN_SLIGHT_RIGHT':
      return 'Bear right';
    case 'TURN_SHARP_LEFT':
      return 'Sharp left';
    case 'TURN_SHARP_RIGHT':
      return 'Sharp right';
    case 'UTURN_LEFT':
    case 'UTURN_RIGHT':
      return 'Make a U-turn';
    case 'ROUNDABOUT_LEFT':
    case 'ROUNDABOUT_RIGHT':
      return 'Enter the roundabout';
    case 'DEPART':
      return 'Head toward the destination';
    case 'ARRIVE':
      return 'You have arrived';
    default:
      return maneuver.isEmpty ? 'Continue' : 'Continue';
  }
}
