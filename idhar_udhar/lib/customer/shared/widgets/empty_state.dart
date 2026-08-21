import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/constants/asset_paths.dart';
import 'package:idhar_udhar/customer/core/theme/theme.dart';
import 'package:idhar_udhar/customer/core/widgets/safe_asset_image.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.subtitle,
    super.key,
    this.imagePath = AssetPaths.parcel,
    this.action,
  });

  final String title;
  final String subtitle;
  final String imagePath;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeAssetImage(path: imagePath, height: 120, fit: BoxFit.contain),
            const SizedBox(height: AppSpacing.xl),
            Text(title, style: AppTextStyles.headingS, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
