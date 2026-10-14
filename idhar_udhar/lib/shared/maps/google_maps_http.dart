import 'package:dio/dio.dart';

import 'maps_platform.dart';
import 'maps_runtime.dart';

/// Isolated Dio client for Google Maps web services (Places / Routes / Geocoding).
///
/// Uses the Android-restricted Maps key with package + cert headers.
/// Never logs the API key.
class GoogleMapsHttp {
  GoogleMapsHttp(this._platform, {Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: const <String, dynamic>{
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final MapsPlatform _platform;
  final Dio _dio;

  /// Same request as [post], with the failure category kept.
  ///
  /// Does not log the key, certificate, or response message.
  Future<MapsHttpOutcome> postOutcome({
    required String url,
    required Object data,
    String? fieldMask,
  }) async {
    final MapsAuthHeaders? auth = await _platform.authHeaders();
    if (auth == null || !auth.hasKey || MapsRuntime.isFlutterTest) {
      return const MapsHttpOutcome.missingConfig();
    }
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        url,
        data: data,
        options: Options(headers: _headers(auth, fieldMask: fieldMask)),
      );
      final int? code = response.statusCode;
      if (code != null && code >= 400) {
        return MapsHttpOutcome.http(
          statusCode: code,
          errorStatus: sanitizedGoogleStatus(response.data),
          data: response.data,
        );
      }
      return MapsHttpOutcome.success(statusCode: code ?? 200, data: response.data);
    } on DioException catch (error) {
      return MapsHttpOutcome.http(
        statusCode: error.response?.statusCode,
        errorStatus: sanitizedGoogleStatus(error.response?.data),
      );
    } catch (_) {
      return const MapsHttpOutcome.transport();
    }
  }

  Future<Response<dynamic>?> post({
    required String url,
    required Object data,
    String? fieldMask,
  }) async {
    final MapsAuthHeaders? auth = await _platform.authHeaders();
    if (auth == null || MapsRuntime.isFlutterTest) {
      return null;
    }
    try {
      return await _dio.post<dynamic>(
        url,
        data: data,
        options: Options(headers: _headers(auth, fieldMask: fieldMask)),
      );
    } on DioException {
      return null;
    }
  }

  Future<Response<dynamic>?> get({
    required String url,
    Map<String, dynamic>? query,
    String? fieldMask,
    bool includeKeyQuery = false,
  }) async {
    final MapsAuthHeaders? auth = await _platform.authHeaders();
    if (auth == null || MapsRuntime.isFlutterTest) {
      return null;
    }
    final Map<String, dynamic> params = <String, dynamic>{
      ...?query,
      if (includeKeyQuery) 'key': auth.apiKey,
    };
    try {
      return await _dio.get<dynamic>(
        url,
        queryParameters: params,
        options: Options(headers: _headers(auth, fieldMask: fieldMask)),
      );
    } on DioException {
      return null;
    }
  }

  Map<String, String> _headers(
    MapsAuthHeaders auth, {
    String? fieldMask,
  }) {
    return <String, String>{
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': auth.apiKey,
      if (auth.packageName.isNotEmpty) 'X-Android-Package': auth.packageName,
      if (auth.sha1.isNotEmpty) 'X-Android-Cert': auth.sha1,
      if (fieldMask != null && fieldMask.isNotEmpty)
        'X-Goog-FieldMask': fieldMask,
    };
  }
}

enum MapsHttpFailure { missingConfig, http, transport }

class MapsHttpOutcome {
  const MapsHttpOutcome.success({
    required this.statusCode,
    required this.data,
  })  : failure = null,
        errorStatus = null;

  const MapsHttpOutcome.missingConfig()
      : failure = MapsHttpFailure.missingConfig,
        statusCode = null,
        errorStatus = null,
        data = null;

  const MapsHttpOutcome.http({
    required this.statusCode,
    this.errorStatus,
    this.data,
  }) : failure = MapsHttpFailure.http;

  const MapsHttpOutcome.transport()
      : failure = MapsHttpFailure.transport,
        statusCode = null,
        errorStatus = null,
        data = null;

  final MapsHttpFailure? failure;
  final int? statusCode;
  final String? errorStatus;
  final Object? data;

  bool get isSuccess => failure == null;
}

/// Google's status code only. Drops the message because it can echo the key.
String? sanitizedGoogleStatus(Object? body) {
  if (body is! Map) {
    return null;
  }
  final Object? error = body['error'];
  if (error is Map) {
    final Object? status = error['status'];
    if (status is String && _safeStatusToken(status)) {
      return status;
    }
  }
  final Object? status = body['status'];
  if (status is String && status != 'OK' && _safeStatusToken(status)) {
    return status;
  }
  return null;
}

bool _safeStatusToken(String value) {
  return RegExp(r'^[A-Z0-9_]{1,64}$').hasMatch(value);
}
