import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/format/trip_distance.dart';

void main() {
  test('formats short distances in meters and longer distances in kilometers', () {
    expect(formatTripDistanceKm(0.1), '100 m');
    expect(formatTripDistanceKm(0.25), '250 m');
    expect(formatTripDistanceKm(0.5), '500 m');
    expect(formatTripDistanceKm(0.85), '850 m');
    expect(formatTripDistanceKm(0.999), '999 m');
    expect(formatTripDistanceKm(1), '1.0 km');
    expect(formatTripDistanceKm(1.3), '1.3 km');
    expect(formatTripDistanceKm(3), '3.0 km');
    expect(formatTripDistanceKm(10.2), '10.2 km');
    expect(formatTripDistanceKm(0), '—');
  });
}
