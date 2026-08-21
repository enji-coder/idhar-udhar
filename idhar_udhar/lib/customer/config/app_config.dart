import 'environment.dart';

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

  static String get apiBaseUrl {
    switch (Environment.current) {
      case AppEnvironment.development:
        return 'https://dev-api.idharudhar.local';
      case AppEnvironment.staging:
        return 'https://staging-api.idharudhar.in';
      case AppEnvironment.production:
        return 'https://api.idharudhar.in';
    }
  }

  static bool get isProduction =>
      Environment.current == AppEnvironment.production;

  static bool get enableLogging => !isProduction;
}
