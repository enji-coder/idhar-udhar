import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_config.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/auth_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';

class _IdleTokenStore extends TokenStore {
  @override
  Future<String?> get accessToken async => null;

  @override
  Future<String?> get refreshToken async => null;
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.onFetch);

  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }
}

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

AuthApi _api(_RecordingAdapter adapter) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.normalizeBaseUrl(
        'https://staging-api.idharudhar.co.in/v1',
      ),
    ),
  );
  dio.httpClientAdapter = adapter;
  final TokenStore tokens = _IdleTokenStore();
  return AuthApi(ApiClient(tokenStore: tokens, dio: dio), tokens);
}

void main() {
  const String phone = '9999999999';

  test('rider OTP request uses one /v1 and a 10-digit RIDER body', () async {
    late RequestOptions sent;
    final AuthApi api = _api(
      _RecordingAdapter((RequestOptions options) async {
        sent = options;
        return _json(200, <String, Object?>{
          'requested': true,
          'expires_in_seconds': 300,
          'cooldown_seconds': 30,
          'delivery': 'msg91',
        });
      }),
    );

    final OtpRequestResult result = await api.requestOtp(
      phone: '+91 $phone',
      actor: MarketplaceActor.rider,
    );

    expect(sent.method, 'POST');
    expect(sent.uri.path, '/v1/auth/otp/request');
    expect(
      sent.uri.toString(),
      'https://staging-api.idharudhar.co.in/v1/auth/otp/request',
    );
    expect(sent.data, <String, String>{
      'phone': phone,
      'actor_type': 'RIDER',
    });
    expect(result.requested, isTrue);
    expect(result.delivery, 'msg91');
  });

  test('a missing OTP route stays the visible not-found message', () {
    final ApiException error = ApiErrorMapper.fromBody(
      <String, Object?>{
        'error': <String, Object?>{
          'code': 'NOT_FOUND',
          'message': 'Cannot POST /v1/v1/auth/otp/request',
        },
      },
      statusCode: 404,
    );
    expect(error.code, 'NOT_FOUND');
    expect(error.message, 'We could not find that.');
  });

  test('invalid OTP request fields stay a validation message', () {
    final ApiException error = ApiErrorMapper.fromBody(
      <String, Object?>{
        'error': <String, Object?>{
          'code': 'VALIDATION_ERROR',
          'message': 'Request validation failed',
        },
      },
      statusCode: 400,
    );
    expect(error.message, 'Please check the details and try again.');
  });

  test('a missing rider OTP challenge is not the login not-found message', () {
    final ApiException error = ApiErrorMapper.fromBody(
      <String, Object?>{
        'error': <String, Object?>{
          'code': 'OTP_NOT_FOUND',
          'message': 'No verification challenge was found for this phone.',
        },
      },
      statusCode: 401,
    );
    expect(error.message, 'Request a new code and try again.');
  });
}
