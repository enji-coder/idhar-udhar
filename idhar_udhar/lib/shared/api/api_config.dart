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

  /// Backend development default (`OTP_LENGTH`). Still a business decision.
  static const int otpLength = 6;

  static String get baseUrl {
    final String defined = _definedBaseUrl.trim();
    if (defined.isNotEmpty) {
      return _stripTrailingSlash(defined);
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

  static bool get enableRequestLogging => !kReleaseMode;

  static String _stripTrailingSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}
