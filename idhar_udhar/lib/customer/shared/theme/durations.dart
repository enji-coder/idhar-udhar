import 'package:idhar_udhar/customer/core/animations/app_motion.dart';

/// Named duration tokens for the shared UI kit.
///
/// Mirrors [AppMotion] so feature code never hardcodes milliseconds.
abstract final class AppDurations {
  static const Duration micro = AppMotion.micro;
  static const Duration fast = AppMotion.fast;
  static const Duration normal = AppMotion.normal;
  static const Duration enter = AppMotion.enter;
  static const Duration page = AppMotion.page;
  static const Duration slow = AppMotion.slow;
  static const Duration float = AppMotion.float;
  static const Duration shimmer = AppMotion.shimmer;
}
