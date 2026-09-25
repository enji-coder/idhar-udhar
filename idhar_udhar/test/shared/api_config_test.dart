import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/api/api_config.dart';

void main() {
  test('development base URL is not a hardcoded production host', () {
    expect(ApiConfig.baseUrl.contains('idharudhar.in'), isFalse);
    expect(ApiConfig.baseUrl.startsWith('http://'), isTrue);
  });

  test('OTP length is 4 digits end-to-end with the backend default', () {
    expect(ApiConfig.otpLength, 4);
  });

  test('rider production default is the live API host', () {
    expect(ApiConfig.productionBaseUrl, 'https://api.idharudhar.co.in');
    expect(ApiConfig.productionBaseUrl.contains('localhost'), isFalse);
    ApiConfig.useProductionDefault();
    expect(ApiConfig.baseUrl, 'https://api.idharudhar.co.in');
    ApiConfig.debugResetBaseUrl();
    expect(ApiConfig.baseUrl.contains('idharudhar.in'), isFalse);
  });
}
