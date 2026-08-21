/// Supported build / runtime environments.
enum AppEnvironment {
  development,
  staging,
  production,
}

/// Holds the active [AppEnvironment] for the running process.
///
/// Call [initialize] once from `main` before `runApp`.
abstract final class Environment {
  static AppEnvironment _current = AppEnvironment.development;

  static AppEnvironment get current => _current;

  static bool get isDevelopment => _current == AppEnvironment.development;

  static bool get isStaging => _current == AppEnvironment.staging;

  static bool get isProduction => _current == AppEnvironment.production;

  static void initialize(AppEnvironment environment) {
    _current = environment;
  }
}
