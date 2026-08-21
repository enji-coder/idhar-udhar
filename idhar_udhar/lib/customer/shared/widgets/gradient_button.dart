import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_gradients.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/widgets/animated_primary_button.dart';
import 'package:idhar_udhar/customer/core/widgets/primary_button.dart';

/// Primary orange-gradient CTA for the shared UI kit.
///
/// Supports loading, disabled, leading icon, custom size.
/// Delegates to [PrimaryButton] / [AnimatedPrimaryButton].
class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.height = AppSpacing.buttonHeight,
    this.showArrow = true,
    this.leading,
    this.icon,
    this.gradient = AppGradients.primaryCta,
    this.animated = true,
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
  final IconData? icon;
  final Gradient gradient;
  final bool animated;
  final bool enableHaptic;

  Widget? get _leading {
    if (leading != null) {
      return leading;
    }
    if (icon == null) {
      return null;
    }
    return Icon(icon, color: Colors.white, size: AppSpacing.iconMd);
  }

  @override
  Widget build(BuildContext context) {
    if (animated) {
      return AnimatedPrimaryButton(
        label: label,
        onPressed: onPressed,
        isLoading: isLoading,
        enabled: enabled,
        width: width,
        height: height,
        showArrow: showArrow,
        leading: _leading,
        gradient: gradient,
        enableHaptic: enableHaptic,
      );
    }
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      enabled: enabled,
      width: width,
      height: height,
      showArrow: showArrow,
      leading: _leading,
      gradient: gradient,
    );
  }
}

/// Loading-capable primary CTA (same as [GradientButton] with loading focus).
typedef LoadingButton = GradientButton;
