import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';

class _MemoryTokenStore extends TokenStore {
  _MemoryTokenStore() {
    access = 'access-token';
    refresh = 'refresh-token';
  }

  String? access;
  String? refresh;

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<bool> get hasRefreshToken async =>
      refresh != null && refresh!.isNotEmpty;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? role,
    String? phone,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options) _onFetch;
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    if (calls > 6) {
      throw StateError('infinite auth retry loop');
    }
    return _onFetch(options);
  }
}

ResponseBody _json(int status, String body, {String? requestId}) {
  return ResponseBody.fromString(
    body,
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      if (requestId != null) 'x-request-id': <String>[requestId],
    },
  );
}

void main() {
  test('session 401 with rotating tokens retries once then fails', () async {
    final _MemoryTokenStore tokens = _MemoryTokenStore();
    final Dio dio = Dio(
      BaseOptions(baseUrl: 'https://api.idharudhar.co.in'),
    );
    final _RecordingAdapter adapter = _RecordingAdapter((options) async {
      if (options.path.contains('/v1/auth/token/refresh')) {
        return _json(
          200,
          '{"access_token":"next-access","refresh_token":"next-refresh","role":"CUSTOMER"}',
        );
      }
      return _json(
        401,
        '{"error":{"code":"UNAUTHENTICATED","message":"Missing bearer access token"}}',
      );
    });
    dio.httpClientAdapter = adapter;
    final ApiClient client = ApiClient(tokenStore: tokens, dio: dio);

    await expectLater(
      client.get('/v1/auth/session'),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.calls, lessThanOrEqualTo(3));
    expect(await tokens.hasRefreshToken, isFalse);
  });

  test('timeouts stay distinct and are not retried', () async {
    final List<String> logs = <String>[];
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.idharudhar.co.in'));
    final _RecordingAdapter adapter = _RecordingAdapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
        message: 'Bearer secret-token',
      );
    });
    dio.httpClientAdapter = adapter;
    final ApiClient client = ApiClient(
      tokenStore: _MemoryTokenStore(),
      dio: dio,
      diagnosticLog: logs.add,
    );

    await expectLater(
      client.get('/v1/rider/offers'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.code,
          'code',
          'CONNECTION_TIMEOUT',
        ),
      ),
    );
    expect(adapter.calls, 1);
    expect(logs, isNotEmpty);
    final String line = logs.join('\n');
    expect(line, contains('method=GET'));
    expect(line, contains('path=/v1/rider/offers'));
    expect(line, contains('error=connectionTimeout'));
    expect(line, isNot(contains('Bearer')));
    expect(line, isNot(contains('secret-token')));
    expect(line, isNot(contains('Authorization')));
  });

  test('receive timeout is not reported as a connection timeout', () async {
    final Dio dio = Dio();
    dio.httpClientAdapter = _RecordingAdapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    });
    final ApiClient client = ApiClient(
      tokenStore: _MemoryTokenStore(),
      dio: dio,
      diagnosticLog: (_) {},
    );
    await expectLater(
      client.get('/v1/rider/earnings'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.code,
          'code',
          'RECEIVE_TIMEOUT',
        ),
      ),
    );
  });

  test('identical in-flight GETs share one request and POSTs do not', () async {
    final Completer<ResponseBody> offers = Completer<ResponseBody>();
    int gets = 0;
    int posts = 0;
    final Dio dio = Dio();
    dio.httpClientAdapter = _RecordingAdapter((options) async {
      if (options.method == 'GET') {
        gets += 1;
        return offers.future;
      }
      posts += 1;
      return _json(200, '{"ok":true}');
    });
    final ApiClient client = ApiClient(
      tokenStore: _MemoryTokenStore(),
      dio: dio,
      diagnosticLog: (_) {},
    );
    final Future<Map<String, Object?>> first = client.get('/v1/rider/offers');
    final Future<Map<String, Object?>> second = client.get('/v1/rider/offers');
    for (int i = 0; i < 20 && gets == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(gets, 1);
    offers.complete(
      _json(
        200,
        '{"offers":[]}',
        requestId: 'req-safe-1',
      ),
    );
    await Future.wait(<Future<Map<String, Object?>>>[first, second]);
    await Future.wait(<Future<Map<String, Object?>>>[
      client.post('/v1/rider/location', data: <String, Object?>{'latitude': 1}),
      client.post('/v1/rider/location', data: <String, Object?>{'latitude': 2}),
    ]);
    expect(posts, 2);
  });

  test('diagnostic log keeps the request id and drops secrets', () async {
    final List<String> logs = <String>[];
    final Dio dio = Dio();
    dio.httpClientAdapter = _RecordingAdapter((options) async {
      return _json(200, '{"offers":[]}', requestId: 'req-safe-2');
    });
    final ApiClient client = ApiClient(
      tokenStore: _MemoryTokenStore(),
      dio: dio,
      diagnosticLog: logs.add,
    );
    await client.get('/v1/rider/offers');
    expect(logs.single, contains('request_id=req-safe-2'));
    expect(logs.single, contains('status=200'));
    expect(logs.single, contains('duration_ms='));
    expect(logs.single, isNot(contains('access-token')));
  });
}
