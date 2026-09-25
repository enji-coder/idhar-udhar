import 'geo_point.dart';
import 'google_maps_http.dart';
import 'maps_runtime.dart';

/// Places API (New) autocomplete + place details. Falls back to empty on errors.
class PlacesService {
  PlacesService(this._http);

  static const String _autocompleteUrl =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const String _placeUrl = 'https://places.googleapis.com/v1/places';

  final GoogleMapsHttp _http;

  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    GeoPoint? bias,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.length < 2 || MapsRuntime.isFlutterTest) {
      return const <PlaceSuggestion>[];
    }
    final Map<String, Object?> body = <String, Object?>{
      'input': trimmed,
      'includedRegionCodes': <String>['in'],
      'languageCode': 'en',
      if (bias != null)
        'locationBias': <String, Object?>{
          'circle': <String, Object?>{
            'center': <String, Object?>{
              'latitude': bias.latitude,
              'longitude': bias.longitude,
            },
            'radius': 25000.0,
          },
        },
    };
    final response = await _http.post(
      url: _autocompleteUrl,
      data: body,
      fieldMask:
          'suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat',
    );
    final Object? data = response?.data;
    if (data is! Map) {
      return const <PlaceSuggestion>[];
    }
    return parseSuggestions(data);
  }

  Future<ResolvedAddress?> placeDetails(String placeId) async {
    final String id = placeId.trim();
    if (id.isEmpty || MapsRuntime.isFlutterTest) {
      return null;
    }
    final String encoded = Uri.encodeComponent(id);
    final response = await _http.get(
      url: '$_placeUrl/$encoded',
      fieldMask: 'id,formattedAddress,location,displayName',
    );
    final Object? data = response?.data;
    if (data is! Map) {
      return null;
    }
    return parsePlaceDetails(data);
  }

  static List<PlaceSuggestion> parseSuggestions(Map<dynamic, dynamic> json) {
    final Object? suggestions = json['suggestions'];
    if (suggestions is! List) {
      return const <PlaceSuggestion>[];
    }
    final List<PlaceSuggestion> out = <PlaceSuggestion>[];
    for (final Object? item in suggestions) {
      if (item is! Map) {
        continue;
      }
      final Object? prediction = item['placePrediction'];
      if (prediction is! Map) {
        continue;
      }
      final String placeId = '${prediction['placeId'] ?? ''}'.trim();
      if (placeId.isEmpty) {
        continue;
      }
      final Object? structured = prediction['structuredFormat'];
      String primary = '';
      String secondary = '';
      if (structured is Map) {
        primary = _textOf(structured['mainText']);
        secondary = _textOf(structured['secondaryText']);
      }
      if (primary.isEmpty) {
        primary = _textOf(prediction['text']);
      }
      if (primary.isEmpty) {
        continue;
      }
      out.add(
        PlaceSuggestion(
          placeId: placeId,
          primaryText: primary,
          secondaryText: secondary,
        ),
      );
    }
    return out;
  }

  static ResolvedAddress? parsePlaceDetails(Map<dynamic, dynamic> json) {
    final Object? location = json['location'];
    if (location is! Map) {
      return null;
    }
    final double? lat = (location['latitude'] as num?)?.toDouble();
    final double? lng = (location['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      return null;
    }
    final String formatted = '${json['formattedAddress'] ?? ''}'.trim();
    final String display = _textOf(json['displayName']);
    final String address =
        formatted.isNotEmpty ? formatted : (display.isNotEmpty ? display : '');
    if (address.isEmpty) {
      return null;
    }
    return ResolvedAddress(
      latitude: lat,
      longitude: lng,
      address: address,
    );
  }

  static String _textOf(Object? value) {
    if (value is Map) {
      return '${value['text'] ?? ''}'.trim();
    }
    if (value is String) {
      return value.trim();
    }
    return '';
  }
}
