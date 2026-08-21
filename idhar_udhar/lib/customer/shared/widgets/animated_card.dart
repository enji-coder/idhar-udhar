import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/animations/fade_animation.dart';
import 'package:idhar_udhar/customer/core/animations/scale_animation.dart';
import 'package:idhar_udhar/customer/core/animations/slide_animation.dart';

import 'glass_container.dart';

/// Glass card with optional entrance animation (fade / slide / scale).
class AnimatedCard extends StatelessWidget {
  const AnimatedCard({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.borderRadius,
    this.animate = true,
    this.animation = AnimatedCardMotion.slideFade,
    this.delay = Duration.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool animate;
  final AnimatedCardMotion animation;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final Widget card = GlassContainer(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      child: child,
    );

    if (!animate) {
      return card;
    }

    switch (animation) {
      case AnimatedCardMotion.fade:
        return FadeAnimation(delay: delay, child: card);
      case AnimatedCardMotion.scale:
        return ScaleAnimation(delay: delay, child: card);
      case AnimatedCardMotion.slideFade:
        return SlideAnimation(delay: delay, child: card);
    }
  }
}

enum AnimatedCardMotion {
  fade,
  scale,
  slideFade,
}
