import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/glass_effect.dart';

/// Compact floating glass chip used over onboarding illustrations.
class FloatingGlassCard extends StatelessWidget {
  const FloatingGlassCard({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding,
    this.maxWidth = 200,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final Widget card = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassEffect(
        depth: GlassDepthLevel.normal,
        borderRadius: AppRadius.mdAll,
        showInnerHighlight: true,
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }
    return GestureDetector(onTap: onTap, child: card);
  }
}
