/// Compile-time rider feature switches.
///
/// Online time follows the same `--dart-define` mechanism as `API_BASE_URL`.
/// Staging and production build commands do not pass this define, so the
/// default keeps the feature off. Set
/// `--dart-define=RIDER_ONLINE_TIME_ENABLED=true` only when releasing it.
abstract final class RiderFeatures {
  static const bool onlineTimeEnabled = bool.fromEnvironment(
    'RIDER_ONLINE_TIME_ENABLED',
    defaultValue: false,
  );
}
