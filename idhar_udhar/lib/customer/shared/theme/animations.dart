import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:idhar_udhar/customer/core/animations/animations.dart';
import 'package:idhar_udhar/customer/core/routing/route_transitions.dart';

import 'durations.dart';

export 'package:idhar_udhar/customer/core/animations/animations.dart';

/// Animation helpers and curve tokens for the shared UI kit.
///
/// Prefer these wrappers over writing one-off animation code in screens.
abstract final class AppAnimations {
  static const Curve easeOut = AppMotion.easeOut;
  static const Curve easeInOut = AppMotion.easeInOut;
  static const Curve easeOutCubic = AppMotion.easeOutCubic;
  static const Curve spring = AppMotion.spring;
  static const Curve linear = AppMotion.linear;

  static const double pressScale = AppMotion.pressScale;
  static const double enterSlide = AppMotion.enterSlide;
  static const double floatOffset = AppMotion.floatOffset;

  static Widget fade({
    required Widget child,
    Key? key,
    Duration duration = AppDurations.enter,
    Duration delay = Duration.zero,
    Curve curve = AppMotion.easeOut,
  }) {
    return FadeAnimation(
      key: key,
      duration: duration,
      delay: delay,
      curve: curve,
      child: child,
    );
  }

  static Widget slide({
    required Widget child,
    Key? key,
    SlideDirection direction = SlideDirection.fromBottom,
    Duration duration = AppDurations.enter,
    Duration delay = Duration.zero,
    double offset = AppMotion.enterSlide,
    bool fade = true,
  }) {
    return SlideAnimation(
      key: key,
      direction: direction,
      duration: duration,
      delay: delay,
      offset: offset,
      fade: fade,
      child: child,
    );
  }

  static Widget scale({
    required Widget child,
    Key? key,
    Duration duration = AppDurations.fast,
    Duration delay = Duration.zero,
    double begin = 0.86,
    double end = 1,
    bool repeat = false,
  }) {
    return ScaleAnimation(
      key: key,
      duration: duration,
      delay: delay,
      begin: begin,
      end: end,
      repeat: repeat,
      child: child,
    );
  }

  static Widget heroLogo({required Widget child, Key? key}) {
    return AppHero.logo(key: key, child: child);
  }

  static Widget heroVehicle({
    required String vehicleId,
    required Widget child,
    Key? key,
  }) {
    return AppHero.vehicle(key: key, vehicleId: vehicleId, child: child);
  }

  static CustomTransitionPage<void> fadePage({
    required LocalKey key,
    required Widget child,
    Duration duration = AppDurations.page,
  }) {
    return RouteTransitions.fadeThrough(
      key: key,
      child: child,
      duration: duration,
    );
  }

  static CustomTransitionPage<void> slidePage({
    required LocalKey key,
    required Widget child,
    Duration duration = AppDurations.page,
  }) {
    return RouteTransitions.sharedAxisHorizontal(
      key: key,
      child: child,
      duration: duration,
    );
  }
}
