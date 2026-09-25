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

ResponseBody _json(int status, String body) {
  return ResponseBody.fromString(
    body,
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
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
}
