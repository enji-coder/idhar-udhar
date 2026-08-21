import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../animations/app_motion.dart';

/// Shared page transitions aligned with animation guidelines.
abstract final class RouteTransitions {
  static CustomTransitionPage<void> fadeThrough({
    required LocalKey key,
    required Widget child,
    Duration duration = AppMotion.page,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final Animation<double> curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.easeInOut,
        );
        return FadeTransition(
          opacity: curved,
          child: child,
        );
      },
    );
  }

  static CustomTransitionPage<void> sharedAxisHorizontal({
    required LocalKey key,
    required Widget child,
    Duration duration = AppMotion.page,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final Animation<Offset> slide = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: AppMotion.easeOutCubic),
        );
        final Animation<double> fade = CurvedAnimation(
          parent: animation,
          curve: AppMotion.easeOut,
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }
}
