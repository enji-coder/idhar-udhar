import 'dart:async';

import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Direction for [SlideAnimation].
enum SlideDirection {
  fromBottom,
  fromTop,
  fromLeft,
  fromRight,
}

/// Soft slide entrance matching auth card and onboarding motion.
class SlideAnimation extends StatefulWidget {
  const SlideAnimation({
    required this.child,
    super.key,
    this.direction = SlideDirection.fromBottom,
    this.duration = AppMotion.enter,
    this.delay = Duration.zero,
    this.curve = AppMotion.easeOutCubic,
    this.offset = AppMotion.enterSlide,
    this.fade = true,
    this.autoPlay = true,
  });

  final Widget child;
  final SlideDirection direction;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double offset;
  final bool fade;
  final bool autoPlay;

  @override
  State<SlideAnimation> createState() => _SlideAnimationState();
}

class _SlideAnimationState extends State<SlideAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _opacity;
  Timer? _delayTimer;

  Offset get _begin {
    switch (widget.direction) {
      case SlideDirection.fromBottom:
        return Offset(0, widget.offset / 100);
      case SlideDirection.fromTop:
        return Offset(0, -widget.offset / 100);
      case SlideDirection.fromLeft:
        return Offset(-widget.offset / 100, 0);
      case SlideDirection.fromRight:
        return Offset(widget.offset / 100, 0);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
    _slide = Tween<Offset>(begin: _begin, end: Offset.zero).animate(curved);
    _opacity =
        Tween<double>(begin: widget.fade ? 0 : 1, end: 1).animate(curved);
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
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
