import 'package:flutter/services.dart';

import 'geo_point.dart';
import 'maps_runtime.dart';

class MapsAuthHeaders {
  const MapsAuthHeaders({
    required this.apiKey,
    required this.packageName,
    required this.sha1,
  });

  final String apiKey;
  final String packageName;

  /// SHA-1 fingerprint without colons, used only as X-Android-Cert.
  final String sha1;

  bool get hasKey => apiKey.trim().isNotEmpty;
}

/// Native Android bridge for Maps auth headers, GPS, and OS geocoding.
class MapsPlatform {
  MapsPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('idhar_udhar/maps');

  final MethodChannel _channel;
  MapsAuthHeaders? _cachedAuth;

  Future<MapsAuthHeaders?> authHeaders() async {
    if (MapsRuntime.isFlutterTest || !MapsRuntime.useNativeLocation) {
      return _cachedAuth;
    }
    if (_cachedAuth != null) {
      return _cachedAuth;
    }
    try {
      final Object? raw = await _channel.invokeMethod<Object>('getAuthHeaders');
      if (raw is! Map) {
        return null;
      }
      final Map<Object?, Object?> map = raw;
      final String apiKey = (map['apiKey'] as String? ?? '').trim();
      final String packageName = (map['packageName'] as String? ?? '').trim();
      final String sha1 = (map['sha1'] as String? ?? '').trim();
      if (apiKey.isEmpty) {
        return null;
      }
      _cachedAuth = MapsAuthHeaders(
        apiKey: apiKey,
        packageName: packageName,
        sha1: sha1,
      );
      return _cachedAuth;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> isLocationServiceEnabled() async {
    if (MapsRuntime.isFlutterTest) {
      return true;
    }
    if (!MapsRuntime.useNativeLocation) {
      return false;
    }
    try {
      final bool? enabled =
          await _channel.invokeMethod<bool>('isLocationServiceEnabled');
      return enabled ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<LocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (MapsRuntime.isFlutterTest) {
      return const LocationResult.fail(LocationFailure.unavailable);
    }
    if (!MapsRuntime.useNativeLocation) {
      return const LocationResult.fail(LocationFailure.unavailable);
    }
    try {
      final Object? raw = await _channel
          .invokeMethod<Object>('getCurrentLocation', <String, Object>{
        'timeoutMs': timeout.inMilliseconds,
      });
      if (raw is! Map) {
        return const LocationResult.fail(LocationFailure.unavailable);
      }
      final Map<Object?, Object?> map = raw;
      final double? lat = (map['latitude'] as num?)?.toDouble();
      final double? lng = (map['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return const LocationResult.fail(LocationFailure.unavailable);
      }
      return LocationResult.ok(
        DeviceLocation(
          latitude: lat,
          longitude: lng,
          accuracy: (map['accuracy'] as num?)?.toDouble(),
        ),
      );
    } on MissingPluginException {
      return const LocationResult.fail(LocationFailure.unavailable);
    } on PlatformException catch (error) {
      return LocationResult.fail(_mapError(error.code));
    }
  }

  Future<ResolvedAddress?> reverseGeocode(GeoPoint point) async {
    if (MapsRuntime.isFlutterTest || !MapsRuntime.useNativeLocation) {
      return null;
    }
    try {
      final Object? raw =
          await _channel.invokeMethod<Object>('reverseGeocode', <String, Object>{
        'latitude': point.latitude,
        'longitude': point.longitude,
      });
      return _parseResolved(raw, point.latitude, point.longitude);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<ResolvedAddress?> forwardGeocode(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty ||
        MapsRuntime.isFlutterTest ||
        !MapsRuntime.useNativeLocation) {
      return null;
    }
    try {
      final Object? raw =
          await _channel.invokeMethod<Object>('forwardGeocode', <String, Object>{
        'query': trimmed,
      });
      return _parseResolved(raw, null, null);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  ResolvedAddress? _parseResolved(
    Object? raw,
    double? fallbackLat,
    double? fallbackLng,
  ) {
    if (raw is! Map) {
      return null;
    }
    final Map<Object?, Object?> map = raw;
    final String address = (map['address'] as String? ?? '').trim();
    final double? lat =
        (map['latitude'] as num?)?.toDouble() ?? fallbackLat;
    final double? lng =
        (map['longitude'] as num?)?.toDouble() ?? fallbackLng;
    if (address.isEmpty || lat == null || lng == null) {
      return null;
    }
    return ResolvedAddress(
      latitude: lat,
      longitude: lng,
      address: address,
      city: (map['city'] as String? ?? '').trim(),
    );
  }

  LocationFailure _mapError(String code) {
    switch (code) {
      case 'PERMISSION_DENIED':
        return LocationFailure.permissionDenied;
      case 'SERVICE_DISABLED':
        return LocationFailure.serviceDisabled;
      case 'TIMEOUT':
        return LocationFailure.timeout;
      default:
        return LocationFailure.unavailable;
    }
  }
}
