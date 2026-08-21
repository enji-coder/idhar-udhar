import 'package:flutter/material.dart';

import '../animations/hero_animation.dart';
import '../animations/scale_animation.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/glass_effect.dart';
import 'ambient_glow.dart';
import 'safe_asset_image.dart';

/// Floating glass vehicle tile with ambient glow + contact shadow.
class VehicleCard extends StatelessWidget {
  const VehicleCard({
    required this.title,
    required this.selected,
    required this.onTap,
    super.key,
    this.subtitle,
    this.image,
    this.imagePath,
    this.vehicleId,
    this.width = 118,
    this.height = 158,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? image;
  final String? imagePath;
  final String? vehicleId;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Widget iconFallback = Icon(
      Icons.local_shipping_rounded,
      size: 48,
      color: selected ? AppColors.orange : AppColors.navy,
    );

    final Widget visual = image ??
        (imagePath != null
            ? SafeAssetImage(
                path: imagePath!,
                fit: BoxFit.contain,
                fallback: iconFallback,
              )
            : iconFallback);

    final Widget heroChild = vehicleId == null
        ? visual
        : AppHero.vehicle(vehicleId: vehicleId!, child: visual);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: width,
          height: height,
          child: GlassEffect(
            intensity:
                selected ? GlassIntensity.heavy : GlassIntensity.medium,
            depth: selected ? GlassDepthLevel.hero : GlassDepthLevel.normal,
            borderRadius: AppRadius.lgAll,
            showShadow: true,
            showAmbientGlow: selected,
            ambientColor: AppColors.orange,
            showInnerHighlight: true,
            borderColor: selected
                ? AppColors.orange
                : AppColors.white.withValues(alpha: 0.45),
            borderWidth: selected ? 1.6 : 1.1,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AmbientGlow(
                          diameter: width * 0.85,
                          opacity: selected ? 0.28 : 0.12,
                          color: AppColors.orange,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: height * 0.42,
                                child: heroChild,
                              ),
                              Container(
                                width: width * 0.42,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: AppShadows.assetContact,
                                  color: AppColors.navy.withValues(alpha: 0.08),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingS.copyWith(
                        fontSize: 13,
                        color: selected ? AppColors.navy : AppColors.navy,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: selected
                              ? AppColors.orange
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (selected)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: ScaleAnimation(
                      begin: 0.6,
                      child: _SelectedBadge(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.orange,
        shape: BoxShape.circle,
        boxShadow: AppShadows.orangeGlow,
      ),
      child: const Icon(Icons.check_rounded, size: 14, color: AppColors.white),
    );
  }
}
