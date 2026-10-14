import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/maps/geo_point.dart';
import 'package:idhar_udhar/shared/maps/google_maps_http.dart';
import 'package:idhar_udhar/shared/maps/places_service.dart';
import 'package:idhar_udhar/shared/maps/polyline_codec.dart';
import 'package:idhar_udhar/shared/maps/routes_service.dart';

void main() {
  test('decodes a Google encoded polyline', () {
    const String encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
    final points = PolylineCodec.decode(encoded);
    expect(points.length, 3);
    expect(points[0].latitude, closeTo(38.5, 0.01));
    expect(points[0].longitude, closeTo(-120.2, 0.01));
    expect(points[1].latitude, closeTo(40.7, 0.01));
    expect(points[1].longitude, closeTo(-120.95, 0.01));
    expect(points[2].latitude, closeTo(43.252, 0.01));
    expect(points[2].longitude, closeTo(-126.453, 0.01));
  });

  test('parses Places API (New) autocomplete suggestions', () {
    final suggestions = PlacesService.parseSuggestions(<String, Object?>{
      'suggestions': <Object?>[
        <String, Object?>{
          'placePrediction': <String, Object?>{
            'placeId': 'abc',
            'structuredFormat': <String, Object?>{
              'mainText': <String, Object?>{'text': 'CG Road'},
              'secondaryText': <String, Object?>{'text': 'Ahmedabad'},
            },
          },
        },
      ],
    });
    expect(suggestions, hasLength(1));
    expect(suggestions.first.placeId, 'abc');
    expect(suggestions.first.primaryText, 'CG Road');
    expect(suggestions.first.secondaryText, 'Ahmedabad');
  });

  test('parses Routes API display payload without using it for fare', () {
    final route = RoutesService.parseRoute(<String, Object?>{
      'routes': <Object?>[
        <String, Object?>{
          'distanceMeters': 7800,
          'duration': '1440s',
          'polyline': <String, Object?>{
            'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
          },
        },
      ],
    });
    expect(route, isNotNull);
    expect(route!.distanceMeters, 7800);
    expect(route.durationSeconds, 1440);
    expect(route.etaMinutes, 24);
    expect(route.points.length, 3);
  });

  test('guidance distinguishes route outcomes without leaking credentials', () {
    const String encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
    final RouteGuidanceResult rejected = RoutesService.interpretGuidance(
      const MapsHttpOutcome.http(
        statusCode: 403,
        errorStatus: 'PERMISSION_DENIED',
      ),
    );
    expect(rejected.kind, RouteGuidanceKind.httpRejected);
    expect(rejected.httpStatus, 403);
    expect(rejected.errorStatus, 'PERMISSION_DENIED');
    expect(rejected.route, isNull);

    final RouteGuidanceResult empty = RoutesService.interpretGuidance(
      const MapsHttpOutcome.success(
        statusCode: 200,
        data: <String, Object?>{'routes': <Object?>[]},
      ),
    );
    expect(empty.kind, RouteGuidanceKind.noRoute);

    final RouteGuidanceResult malformed = RoutesService.interpretGuidance(
      const MapsHttpOutcome.success(
        statusCode: 200,
        data: <String, Object?>{
          'routes': <Object?>[
            <String, Object?>{
              'distanceMeters': 10,
              'duration': 'later',
              'polyline': <String, Object?>{'encodedPolyline': encoded},
            },
          ],
        },
      ),
    );
    expect(malformed.kind, RouteGuidanceKind.malformed);

    final RouteGuidanceResult zero = RoutesService.interpretGuidance(
      MapsHttpOutcome.success(
        statusCode: 200,
        data: <String, Object?>{
          'routes': <Object?>[
            <String, Object?>{
              'distanceMeters': 0,
              'duration': '0s',
              'polyline': <String, Object?>{'encodedPolyline': encoded},
            },
          ],
        },
      ),
    );
    expect(zero.kind, RouteGuidanceKind.success);
    expect(zero.distanceMeters, 0);
    expect(zero.pointCount, greaterThanOrEqualTo(2));
    expect(
      RoutesService.parseRoute(<String, Object?>{
        'routes': <Object?>[
          <String, Object?>{
            'distanceMeters': 0,
            'duration': '0s',
            'polyline': <String, Object?>{'encodedPolyline': encoded},
          },
        ],
      }),
      isNull,
    );

    final RouteGuidanceResult ok = RoutesService.interpretGuidance(
      MapsHttpOutcome.success(
        statusCode: 200,
        data: <String, Object?>{
          'routes': <Object?>[
            <String, Object?>{
              'distanceMeters': 1200,
              'duration': '180s',
              'polyline': <String, Object?>{'encodedPolyline': encoded},
              'legs': <Object?>[
                <String, Object?>{
                  'steps': <Object?>[
                    <String, Object?>{
                      'distanceMeters': 200,
                      'navigationInstruction': <String, Object?>{
                        'maneuver': 'TURN_LEFT',
                        'instructions': 'Turn left',
                      },
                      'endLocation': <String, Object?>{
                        'latLng': <String, Object?>{
                          'latitude': 23.03,
                          'longitude': 72.57,
                        },
                      },
                    },
                  ],
                },
              ],
            },
          ],
        },
      ),
    );
    expect(ok.kind, RouteGuidanceKind.success);
    expect(ok.route!.steps.single.instruction, 'Turn left');
    expect(ok.pointCount, greaterThanOrEqualTo(2));

    expect(
      RoutesService.interpretGuidance(const MapsHttpOutcome.missingConfig()).kind,
      RouteGuidanceKind.missingConfig,
    );
    for (final RouteGuidanceKind kind in RouteGuidanceKind.values) {
      final String message = routeGuidanceMessage(kind).toLowerCase();
      expect(message, isNot(contains('key')));
      expect(message, isNot(contains('token')));
      expect(message, isNot(contains('aiza')));
    }
    expect(
      sanitizedGoogleStatus(<String, Object?>{
        'error': <String, Object?>{
          'status': 'PERMISSION_DENIED',
          'message': 'API key AIzaSECRET must stay hidden',
        },
      }),
      'PERMISSION_DENIED',
    );
    expect(ok.route!.route.points, isA<List<GeoPoint>>());
  });
}
