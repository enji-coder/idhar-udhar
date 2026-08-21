import 'package:flutter/material.dart';

/// Lightweight parallax layer driven by a normalized scroll or drag value.
class ParallaxAnimation extends StatelessWidget {
  const ParallaxAnimation({
    required this.child,
    required this.offsetFactor,
    super.key,
    this.axis = Axis.vertical,
    this.intensity = 24,
  });

  /// Value typically in `-1..1` (scroll progress or pointer delta).
  final double offsetFactor;
  final Widget child;
  final Axis axis;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return child;
    }
    final double delta = offsetFactor.clamp(-1.0, 1.0) * intensity;
    final Offset offset =
        axis == Axis.vertical ? Offset(0, delta) : Offset(delta, 0);
    return Transform.translate(offset: offset, child: child);
  }
}

/// Scroll-linked parallax wrapper using a [ScrollController].
class ParallaxScrollLayer extends StatelessWidget {
  const ParallaxScrollLayer({
    required this.controller,
    required this.child,
    super.key,
    this.factor = 0.25,
    this.axis = Axis.vertical,
  });

  final ScrollController controller;
  final Widget child;
  final double factor;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final double pixels = controller.hasClients ? controller.offset : 0;
        return ParallaxAnimation(
          offsetFactor: (pixels / 400).clamp(-1.0, 1.0) * factor,
          axis: axis,
          intensity: 40,
          child: child,
        );
      },
    );
  }
}
