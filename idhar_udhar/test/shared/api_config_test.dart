import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/api/api_config.dart';

void main() {
  test('development base URL is not a hardcoded production host', () {
    expect(ApiConfig.baseUrl.contains('idharudhar.in'), isFalse);
    expect(ApiConfig.baseUrl.startsWith('http://'), isTrue);
  });

  test('OTP length matches backend development default', () {
    expect(ApiConfig.otpLength, 6);
  });
}
