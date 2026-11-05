import 'package:dio/dio.dart';
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

  test('rider staging default is explicit and does not replace production', () {
    expect(ApiConfig.stagingBaseUrl, 'https://staging-api.idharudhar.co.in');
    expect(ApiConfig.productionBaseUrl, 'https://api.idharudhar.co.in');
    ApiConfig.useStagingDefault();
    expect(ApiConfig.baseUrl, 'https://staging-api.idharudhar.co.in');
    ApiConfig.debugResetBaseUrl();
    ApiConfig.useProductionDefault();
    expect(ApiConfig.baseUrl, 'https://api.idharudhar.co.in');
    ApiConfig.debugResetBaseUrl();
  });

  test('a base URL that already includes /v1 is not joined twice', () {
    const String releaseBase = 'https://staging-api.idharudhar.co.in/v1';
    expect(
      ApiConfig.normalizeBaseUrl(releaseBase),
      'https://staging-api.idharudhar.co.in',
    );
    expect(
      ApiConfig.normalizeBaseUrl('$releaseBase/'),
      'https://staging-api.idharudhar.co.in',
    );
    expect(
      ApiConfig.normalizeBaseUrl(ApiConfig.stagingBaseUrl),
      ApiConfig.stagingBaseUrl,
    );
    expect(
      ApiConfig.normalizeBaseUrl(ApiConfig.productionBaseUrl),
      ApiConfig.productionBaseUrl,
    );

    final Uri doubled = RequestOptions(
      baseUrl: releaseBase,
      path: '/v1/auth/otp/request',
    ).uri;
    expect(doubled.path, '/v1/v1/auth/otp/request');

    final Uri once = RequestOptions(
      baseUrl: ApiConfig.normalizeBaseUrl(releaseBase),
      path: '/v1/auth/otp/request',
    ).uri;
    expect(
      once.toString(),
      'https://staging-api.idharudhar.co.in/v1/auth/otp/request',
    );
  });
}
