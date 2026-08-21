/// Canonical display IDs. Internal production PKs remain UUID (not implemented here).
abstract final class OrderIds {
  static const String cityCode = 'AMD';
  static const int sequencePad = 10;

  /// Demo sequence only — production uses a database sequence.
  static int _sequence = 10421;

  static void resetDemoSequence([int value = 10421]) {
    _sequence = value;
  }

  static String formatDisplayId(int sequence, {String city = cityCode}) {
    final String padded = sequence.toString().padLeft(sequencePad, '0');
    return 'IU-$city-$padded';
  }

  static String nextDisplayId({String city = cityCode}) {
    final String id = formatDisplayId(_sequence, city: city);
    _sequence += 1;
    return id;
  }
}
