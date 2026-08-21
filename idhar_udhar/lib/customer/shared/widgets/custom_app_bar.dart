import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/app_text_styles.dart';

/// Brand-aware Material 3 app bar for feature screens.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.showBack = true,
    this.onBack,
    this.backgroundColor = Colors.transparent,
    this.foregroundColor = AppColors.navyDeep,
    this.elevation = 0,
    this.systemOverlayStyle,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showBack;
  final VoidCallback? onBack;
  final Color backgroundColor;
  final Color foregroundColor;
  final double elevation;
  final SystemUiOverlayStyle? systemOverlayStyle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    final bool canPop = parentRoute?.canPop ?? false;

    return AppBar(
      title: titleWidget ??
          (title == null
              ? null
              : Text(
                  title!,
                  style:
                      AppTextStyles.headingS.copyWith(color: foregroundColor),
                )),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      scrolledUnderElevation: 0,
      systemOverlayStyle: systemOverlayStyle,
      leading: leading ??
          (showBack && canPop
              ? IconButton(
                  tooltip: 'Back',
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: AppSpacing.iconSm,
                    color: foregroundColor,
                  ),
                )
              : null),
      actions: actions,
    );
  }
}
