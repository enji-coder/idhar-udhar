import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_motion.dart';

/// Press feedback: scale to 0.98 with optional haptic, spring release.
class ButtonPressAnimation extends StatefulWidget {
  const ButtonPressAnimation({
    required this.child,
    super.key,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.scale = AppMotion.pressScale,
    this.duration = AppMotion.micro,
    this.enableHaptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final double scale;
  final Duration duration;
  final bool enableHaptic;

  @override
  State<ButtonPressAnimation> createState() => _ButtonPressAnimationState();
}

class _ButtonPressAnimationState extends State<ButtonPressAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _down() async {
    if (!widget.enabled) {
      return;
    }
    await _controller.forward();
  }

  Future<void> _up() async {
    if (!widget.enabled) {
      return;
    }
    await _controller.reverse();
  }

  void _tap() {
    if (!widget.enabled || widget.onTap == null) {
      return;
    }
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.of(context).disableAnimations;
    final Widget child = reduce
        ? widget.child
        : ScaleTransition(scale: _scale, child: widget.child);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapUp: (_) async {
        await _up();
        _tap();
      },
      onTapCancel: _up,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: child,
    );
  }
}
