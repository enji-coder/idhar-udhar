import 'package:flutter/foundation.dart';

/// Runtime API configuration. Production host is never hardcoded.
///
/// Pass `--dart-define=API_BASE_URL=https://...` for staging/production.
/// Development defaults:
/// - Android emulator → `http://10.0.2.2:3000`
/// - Chrome / desktop / iOS simulator → `http://localhost:3000`
abstract final class ApiConfig {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String cityId = String.fromEnvironment('IU_CITY_ID');
  static const String vehicleCategoryId =
      String.fromEnvironment('IU_VEHICLE_CATEGORY_ID');

  /// Live production API. Rider entry uses this when `API_BASE_URL` is unset.
  static const String productionBaseUrl = 'https://api.idharudhar.co.in';

  /// Temporary testing default. Must match backend `OTP_LENGTH`.
  static const int otpLength = 4;

  static bool _useProductionDefault = false;

  /// Rider startup. Keeps Customer debug on the local default unless
  /// `--dart-define=API_BASE_URL` is passed.
  static void useProductionDefault() {
    if (_definedBaseUrl.trim().isEmpty) {
      _useProductionDefault = true;
    }
  }

  @visibleForTesting
  static void debugResetBaseUrl() {
    _useProductionDefault = false;
  }

  static String get baseUrl {
    final String defined = _definedBaseUrl.trim();
    if (defined.isNotEmpty) {
      return _stripTrailingSlash(defined);
    }
    if (_useProductionDefault) {
      return productionBaseUrl;
    }
    if (kReleaseMode) {
      throw StateError(
        'API_BASE_URL must be provided via --dart-define for release builds',
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static bool get hasCatalogIds =>
      cityId.trim().isNotEmpty && vehicleCategoryId.trim().isNotEmpty;

  /// Capture peek is loopback-only on the API. Never used in release builds.
  static bool get canPeekCapturedOtp {
    if (kReleaseMode) {
      return false;
    }
    final Uri uri = Uri.parse(baseUrl);
    return uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2';
  }

  static bool get enableRequestLogging => !kReleaseMode;

  static String _stripTrailingSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}
