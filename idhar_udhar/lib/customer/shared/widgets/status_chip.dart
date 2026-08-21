import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    super.key,
    this.color = AppColors.orange,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = selected
        ? color
        : AppColors.white.withValues(alpha: 0.18);
    final Color fg = selected ? AppColors.white : AppColors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.pillAll,
            border: Border.all(
              color: selected
                  ? color
                  : AppColors.white.withValues(alpha: 0.35),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
