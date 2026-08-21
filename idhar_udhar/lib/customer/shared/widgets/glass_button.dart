import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/animations/button_press_animation.dart';
import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_radius.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/app_text_styles.dart';
import 'package:idhar_udhar/customer/core/theme/glass_effect.dart';

/// Secondary glass / frosted button.
class GlassButton extends StatelessWidget {
  const GlassButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.height = AppSpacing.buttonHeight,
    this.icon,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final double? width;
  final double height;
  final IconData? icon;
  final Widget? leading;

  bool get _interactive => enabled && !isLoading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    return ButtonPressAnimation(
      enabled: _interactive,
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _interactive ? 1 : 0.55,
        child: SizedBox(
          width: width ?? double.infinity,
          height: height,
          child: IgnorePointer(
            child: GlassEffect(
              intensity: GlassIntensity.soft,
              borderRadius: AppRadius.pillAll,
              showShadow: true,
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.navy,
                        ),
                      )
                    else ...[
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: AppSpacing.sm),
                      ] else if (icon != null) ...[
                        Icon(icon,
                            color: AppColors.navy, size: AppSpacing.iconMd),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.buttonSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
