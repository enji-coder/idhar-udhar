import 'package:idhar_udhar/customer/config/environment.dart';
import 'package:idhar_udhar/shared/api/api_config.dart';

/// Static application metadata and environment-aware endpoints.
///
/// Business and feature logic must not live here.
abstract final class AppConfig {
  static const String appName = 'IDHAR UDHAR';
  static const String appId = 'idhar_udhar';
  static const String organization = 'com.idharudhar';
  static const String tagline = 'Delivering Trust, Every Time';

  static const String versionName = '1.0.0';
  static const int versionCode = 1;

  static String get apiBaseUrl => ApiConfig.baseUrl;

  static bool get isProduction =>
      Environment.current == AppEnvironment.production;

  static bool get enableLogging => !isProduction;
}
