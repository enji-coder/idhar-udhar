import 'package:flutter/material.dart';

import '../animations/button_press_animation.dart';
import '../theme/app_gradients.dart';
import '../theme/app_spacing.dart';
import 'primary_button.dart';

/// [PrimaryButton] wrapped with press-scale and haptic feedback.
class AnimatedPrimaryButton extends StatelessWidget {
  const AnimatedPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.height = AppSpacing.buttonHeight,
    this.showArrow = true,
    this.leading,
    this.gradient = AppGradients.primaryCta,
    this.enableHaptic = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final double? width;
  final double height;
  final bool showArrow;
  final Widget? leading;
  final Gradient gradient;
  final bool enableHaptic;

  @override
  Widget build(BuildContext context) {
    return ButtonPressAnimation(
      enabled: enabled && !isLoading,
      enableHaptic: enableHaptic,
      onTap: onPressed,
      child: IgnorePointer(
        child: PrimaryButton(
          label: label,
          onPressed: onPressed,
          isLoading: isLoading,
          enabled: enabled,
          width: width,
          height: height,
          showArrow: showArrow,
          leading: leading,
          gradient: gradient,
        ),
      ),
    );
  }
}
