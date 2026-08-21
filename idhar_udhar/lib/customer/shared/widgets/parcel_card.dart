import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_radius.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/app_text_styles.dart';
import 'package:idhar_udhar/customer/core/theme/glass_effect.dart';

import 'glass_container.dart';

/// Selectable parcel-type card (documents, small, large, furniture, etc.).
class ParcelCard extends StatelessWidget {
  const ParcelCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
    this.subtitle,
    this.width,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: width,
        child: GlassContainer(
          depth: selected ? GlassDepthLevel.hero : GlassDepthLevel.normal,
          showAmbientGlow: selected,
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: AppRadius.lgAll,
          borderColor: selected ? AppColors.orange : null,
          child: Row(
            children: [
              Container(
                width: AppSpacing.massive,
                height: AppSpacing.massive,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.orange.withOpacity(0.15)
                      : AppColors.softPeach.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? AppColors.orange : AppColors.navy,
                  size: AppSpacing.iconMd,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headingS),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.orange,
                  size: AppSpacing.iconMd,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
