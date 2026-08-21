import 'dart:async';

import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Scale pop for selection checks, OTP focus, and micro-interactions.
class ScaleAnimation extends StatefulWidget {
  const ScaleAnimation({
    required this.child,
    super.key,
    this.duration = AppMotion.fast,
    this.delay = Duration.zero,
    this.curve = AppMotion.spring,
    this.begin = 0.86,
    this.end = 1,
    this.autoPlay = true,
    this.repeat = false,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double begin;
  final double end;
  final bool autoPlay;
  final bool repeat;

  @override
  State<ScaleAnimation> createState() => _ScaleAnimationState();
}

class _ScaleAnimationState extends State<ScaleAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: widget.begin, end: widget.end).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    if (widget.autoPlay) {
      _delayTimer = Timer(widget.delay, () {
        if (!mounted) {
          return;
        }
        if (widget.repeat) {
          _controller.repeat(reverse: true);
        } else {
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
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
