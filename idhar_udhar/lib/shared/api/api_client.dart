import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

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
  })  : _tokenStore = tokenStore,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
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
    if (ApiConfig.enableRequestLogging) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (Object object) {
            _log.d(object);
          },
        ),
      );
    }
  }

  final TokenStore _tokenStore;
  final Dio _dio;
  final Logger _log = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 0),
  );
  SessionInvalidCallback? onSessionInvalid;
  Future<void>? _refreshing;

  Dio get raw => _dio;

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _send(() => _dio.get<dynamic>(path, queryParameters: query));
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
    if (status != 401 || _isAuthPath(error.requestOptions.path)) {
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
      final RequestOptions request = error.requestOptions;
      request.headers['Authorization'] = 'Bearer $token';
      final Response<dynamic> retry = await _dio.fetch<dynamic>(request);
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
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiException(
        code: 'INTERNAL_ERROR',
        message: 'The server took too long. Try again.',
      );
    }
    if (error.type == DioExceptionType.connectionError) {
      return const ApiException(
        code: 'DATABASE_UNAVAILABLE',
        message: 'Cannot reach the server. Check your connection.',
      );
    }
    return ApiErrorMapper.fromBody(
      error.response?.data,
      statusCode: error.response?.statusCode,
    );
  }

  bool _isPublic(String path) {
    return path.contains('/v1/auth/otp/') ||
        path.contains('/v1/auth/token/refresh') ||
        path.endsWith('/health') ||
        path.contains('/health/');
  }

  bool _isAuthPath(String path) {
    return path.contains('/v1/auth/otp/') ||
        path.contains('/v1/auth/token/refresh');
  }
}
