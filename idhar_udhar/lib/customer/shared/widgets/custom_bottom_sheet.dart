import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_radius.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/app_text_styles.dart';

/// Styled modal bottom sheet helper + content scaffold.
abstract final class CustomBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxHeightFactor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (context) {
        final double maxHeight =
            MediaQuery.sizeOf(context).height * (maxHeightFactor ?? 0.9);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 560),
              child: CustomBottomSheetFrame(title: title, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// Visual frame used by [CustomBottomSheet.show].
class CustomBottomSheetFrame extends StatelessWidget {
  const CustomBottomSheetFrame({
    required this.child,
    super.key,
    this.title,
  });

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.md,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.grey,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(title!, style: AppTextStyles.headingM),
              ],
              const SizedBox(height: AppSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
