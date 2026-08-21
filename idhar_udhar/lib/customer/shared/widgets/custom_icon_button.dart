import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/animations/button_press_animation.dart';
import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_radius.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/glass_effect.dart';

/// Circular / rounded icon action button with optional glass fill.
class CustomIconButton extends StatelessWidget {
  const CustomIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.size = AppSpacing.massive,
    this.iconSize = AppSpacing.iconMd,
    this.tooltip,
    this.enabled = true,
    this.glass = true,
    this.backgroundColor,
    this.iconColor = AppColors.navy,
    this.borderRadius,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool enabled;
  final bool glass;
  final Color? backgroundColor;
  final Color iconColor;
  final BorderRadius? borderRadius;

  bool get _interactive => enabled && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? AppRadius.mdAll;

    final Widget child = ButtonPressAnimation(
      enabled: _interactive,
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _interactive ? 1 : 0.45,
        child: SizedBox(
          width: size,
          height: size,
          child: glass
              ? GlassEffect(
                  intensity: GlassIntensity.soft,
                  borderRadius: radius,
                  showShadow: false,
                  padding: EdgeInsets.zero,
                  backgroundColor: backgroundColor,
                  child: Center(
                    child: Icon(icon, size: iconSize, color: iconColor),
                  ),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: backgroundColor ?? AppColors.softPeach,
                    borderRadius: radius,
                  ),
                  child: Center(
                    child: Icon(icon, size: iconSize, color: iconColor),
                  ),
                ),
        ),
      ),
    );

    if (tooltip == null) {
      return child;
    }
    return Tooltip(message: tooltip, child: child);
  }
}
