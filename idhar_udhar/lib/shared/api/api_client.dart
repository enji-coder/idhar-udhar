import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'json_codec.dart';
import 'token_store.dart';

typedef SessionInvalidCallback = Future<void> Function();

/// Authenticated Dio client for Nest `/v1`.
class ApiClient {
  ApiClient({
    required TokenStore tokenStore,
    Dio? dio,
    this.onSessionInvalid,
    void Function(String message)? diagnosticLog,
  })  : _tokenStore = tokenStore,
        _diagnosticLog = diagnosticLog ?? _defaultDiagnosticLog,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: const <String, dynamic>{
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
    _dio.interceptors.add(_SafeApiLog(_diagnosticLog));
  }

  final TokenStore _tokenStore;
  final Dio _dio;
  final void Function(String message) _diagnosticLog;
  final Map<String, Future<Map<String, Object?>>> _inFlightGets =
      <String, Future<Map<String, Object?>>>{};
  SessionInvalidCallback? onSessionInvalid;
  Future<void>? _refreshing;

  static void _defaultDiagnosticLog(String message) {
    developer.log(message, name: 'idhar_udhar.api');
  }

  Dio get raw => _dio;

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, dynamic>? query,
  }) {
    final String key = _getKey(path, query);
    final Future<Map<String, Object?>>? inFlight = _inFlightGets[key];
    if (inFlight != null) {
      return inFlight;
    }
    late final Future<Map<String, Object?>> tracked;
    tracked = _send(
      () => _dio.get<dynamic>(path, queryParameters: query),
    ).whenComplete(() {
      if (identical(_inFlightGets[key], tracked)) {
        _inFlightGets.remove(key);
      }
    });
    _inFlightGets[key] = tracked;
    return tracked;
  }

  Future<Map<String, Object?>> post(
    String path, {
    Object? data,
    Map<String, String>? headers,
  }) {
    return _send(
      () => _dio.post<dynamic>(
        path,
        data: data ?? <String, dynamic>{},
        options: headers == null ? null : Options(headers: headers),
      ),
    );
  }

  Future<Map<String, Object?>> put(
    String path, {
    Object? data,
  }) {
    return _send(() => _dio.put<dynamic>(path, data: data));
  }

  Future<Map<String, Object?>> patch(
    String path, {
    Object? data,
  }) {
    return _send(() => _dio.patch<dynamic>(path, data: data));
  }

  /// Multipart POST. Used by rider document upload. Does not change JSON calls.
  Future<Map<String, Object?>> postForm(
    String path, {
    required FormData data,
  }) {
    return _send(
      () => _dio.post<dynamic>(
        path,
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      ),
    );
  }

  Future<Map<String, Object?>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final Response<dynamic> response = await request();
      return jsonObject(response.data);
    } on DioException catch (error) {
      throw _mapDio(error);
    }
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final String? token = await _tokenStore.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final int? status = error.response?.statusCode;
    final RequestOptions failed = error.requestOptions;
    if (status != 401 ||
        _isAuthPath(failed.path) ||
        failed.extra['iu_auth_retried'] == true) {
      handler.next(error);
      return;
    }
    try {
      await _refreshTokens();
      final String? token = await _tokenStore.accessToken;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          code: 'UNAUTHENTICATED',
          message: 'Please sign in again.',
        );
      }
      failed.headers['Authorization'] = 'Bearer $token';
      failed.extra['iu_auth_retried'] = true;
      final Response<dynamic> retry = await _dio.fetch<dynamic>(failed);
      handler.resolve(retry);
    } catch (_) {
      await _tokenStore.clear();
      final SessionInvalidCallback? callback = onSessionInvalid;
      if (callback != null) {
        unawaited(callback());
      }
      handler.next(error);
    }
  }

  Future<void> _refreshTokens() {
    final Future<void>? inFlight = _refreshing;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<void> future = _doRefresh();
    _refreshing = future;
    return future.whenComplete(() {
      _refreshing = null;
    });
  }

  Future<void> _doRefresh() async {
    final String? refresh = await _tokenStore.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      throw const ApiException(
        code: 'INVALID_REFRESH_TOKEN',
        message: 'Please sign in again.',
      );
    }
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/v1/auth/token/refresh',
        data: <String, String>{'refresh_token': refresh},
      );
      final Map<String, Object?> body = jsonObject(response.data);
      final String? access = jsonString(body['access_token']);
      final String? nextRefresh = jsonString(body['refresh_token']);
      if (access == null ||
          access.isEmpty ||
          nextRefresh == null ||
          nextRefresh.isEmpty) {
        throw const ApiException(
          code: 'INVALID_REFRESH_TOKEN',
          message: 'Please sign in again.',
        );
      }
      await _tokenStore.save(
        accessToken: access,
        refreshToken: nextRefresh,
        role: jsonString(body['role']),
      );
    } on DioException catch (error) {
      throw _mapDio(error);
    }
  }

  ApiException _mapDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return const ApiException(
          code: 'CONNECTION_TIMEOUT',
          message: 'Could not connect to the server. Try again.',
        );
      case DioExceptionType.sendTimeout:
        return const ApiException(
          code: 'SEND_TIMEOUT',
          message: 'The request could not be sent. Try again.',
        );
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          code: 'RECEIVE_TIMEOUT',
          message: 'The server took too long to respond. Try again.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          code: 'CONNECTION_ERROR',
          message: 'Cannot reach the server. Check your connection.',
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        break;
    }
    return ApiErrorMapper.fromBody(
      error.response?.data,
      statusCode: error.response?.statusCode,
    );
  }

  String _getKey(String path, Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) {
      return 'GET $path';
    }
    final List<String> keys = query.keys.map((dynamic key) => '$key').toList()
      ..sort();
    final String encoded = keys
        .map((String key) => '$key=${query[key]}')
        .join('&');
    return 'GET $path?$encoded';
  }

  bool _isPublic(String path) {
    return path.contains('/v1/auth/otp/') ||
        path.contains('/v1/auth/token/refresh') ||
        path.contains('/v1/auth/dev/otp-capture') ||
        path.endsWith('/health') ||
        path.contains('/health/');
  }

  bool _isAuthPath(String path) {
    return path.contains('/v1/auth/otp/') ||
        path.contains('/v1/auth/token/refresh') ||
        path.contains('/v1/auth/dev/otp-capture');
  }
}

/// One completion line per request. Headers, tokens, and bodies are omitted.
class _SafeApiLog extends Interceptor {
  _SafeApiLog(this._emit);

  final void Function(String message) _emit;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['iu_started_ms'] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _emit(
      _line(
        response.requestOptions,
        response.statusCode,
        null,
        response.headers.value('x-request-id'),
      ),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _emit(
      _line(
        err.requestOptions,
        err.response?.statusCode,
        err.type.name,
        err.response?.headers.value('x-request-id'),
      ),
    );
    handler.next(err);
  }

  String _line(
    RequestOptions options,
    int? status,
    String? errorType,
    String? requestId,
  ) {
    final Object? started = options.extra['iu_started_ms'];
    final int durationMs = started is int
        ? DateTime.now().millisecondsSinceEpoch - started
        : -1;
    final StringBuffer line = StringBuffer(
      'api method=${options.method} path=${_path(options)} '
      'status=${status ?? 'none'} duration_ms=$durationMs',
    );
    if (errorType != null && errorType.isNotEmpty) {
      line.write(' error=$errorType');
    }
    final String id = requestId?.trim() ?? '';
    if (id.isNotEmpty && !id.contains(' ') && id.length <= 80) {
      line.write(' request_id=$id');
    }
    return line.toString();
  }

  String _path(RequestOptions options) {
    final String path = options.uri.path;
    if (path.isEmpty) {
      return options.path.split('?').first;
    }
    return path;
  }
}
