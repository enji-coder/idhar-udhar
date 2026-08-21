import 'dart:async';

import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Soft opacity entrance used for glass cards and auth content.
class FadeAnimation extends StatefulWidget {
  const FadeAnimation({
    required this.child,
    super.key,
    this.duration = AppMotion.enter,
    this.delay = Duration.zero,
    this.curve = AppMotion.easeOut,
    this.begin = 0,
    this.end = 1,
    this.autoPlay = true,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double begin;
  final double end;
  final bool autoPlay;

  @override
  State<FadeAnimation> createState() => _FadeAnimationState();
}

class _FadeAnimationState extends State<FadeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: widget.begin, end: widget.end).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    if (widget.autoPlay) {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) {
          _controller.forward();
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
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
