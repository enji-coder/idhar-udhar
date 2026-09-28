import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/data/models/rider_language.dart';

void main() {
  test('maps the stored language codes to profile labels', () {
    expect(riderLanguageLabel('en'), 'English');
    expect(riderLanguageLabel('hi'), 'Hindi');
    expect(riderLanguageLabel('gu'), 'Gujarati');
    expect(riderLanguageCode('Hindi'), 'hi');
    expect(riderLanguageCode(''), isNull);
  });
}
