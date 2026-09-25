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
