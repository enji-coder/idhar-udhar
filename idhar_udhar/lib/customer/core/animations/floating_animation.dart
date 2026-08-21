import 'dart:async';

import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Gentle vertical float for spheres, cards, and decorative elements.
class FloatingAnimation extends StatefulWidget {
  const FloatingAnimation({
    required this.child,
    super.key,
    this.duration = AppMotion.float,
    this.offset = AppMotion.floatOffset,
    this.delay = Duration.zero,
    this.enabled = true,
  });

  final Widget child;
  final Duration duration;
  final double offset;
  final Duration delay;
  final bool enabled;

  @override
  State<FloatingAnimation> createState() => _FloatingAnimationState();
}

class _FloatingAnimationState extends State<FloatingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _dy;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _dy = Tween<double>(begin: -widget.offset, end: widget.offset).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.easeInOut),
    );
    if (widget.enabled) {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) {
          _controller.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _dy,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _dy.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
