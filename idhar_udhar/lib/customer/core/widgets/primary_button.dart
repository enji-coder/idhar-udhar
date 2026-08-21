import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Large capsule CTA with orange gradient, glow, and trailing arrow.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
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
    this.textStyle,
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
  final TextStyle? textStyle;

  bool get _interactive => enabled && !isLoading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: _interactive ? 1 : 0.55,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: AppRadius.pillAll,
          boxShadow: _interactive ? AppShadows.orangeGlow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _interactive ? onPressed : null,
            borderRadius: AppRadius.pillAll,
            splashColor: AppColors.white.withOpacity(0.18),
            highlightColor: AppColors.white.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (isLoading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        label,
                        textAlign:
                            showArrow ? TextAlign.center : TextAlign.center,
                        style: textStyle ?? AppTextStyles.button,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (showArrow && !isLoading) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
