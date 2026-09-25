import 'dart:async';

import 'geo_point.dart';
import 'places_service.dart';

class PlacesSearchSession {
  PlacesSearchSession(this._places);

  final PlacesService _places;
  Timer? _timer;
  int _generation = 0;

  void dispose() {
    _timer?.cancel();
  }

  void query({
    required String text,
    required void Function(List<PlaceSuggestion> suggestions) onResult,
    GeoPoint? bias,
  }) {
    _timer?.cancel();
    final String trimmed = text.trim();
    if (trimmed.length < 2) {
      onResult(const <PlaceSuggestion>[]);
      return;
    }
    final int generation = ++_generation;
    _timer = Timer(const Duration(milliseconds: 380), () async {
      final List<PlaceSuggestion> suggestions = await _places.autocomplete(
        query: trimmed,
        bias: bias,
      );
      if (generation == _generation) {
        onResult(suggestions);
      }
    });
  }
}
