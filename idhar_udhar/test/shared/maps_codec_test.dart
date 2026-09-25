import 'package:flutter_test/flutter_test.dart';
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
}
