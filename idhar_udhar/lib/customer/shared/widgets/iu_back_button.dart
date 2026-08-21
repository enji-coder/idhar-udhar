import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:idhar_udhar/customer/core/theme/theme.dart';

class IuBackButton extends StatelessWidget {
  const IuBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassEffect(
      intensity: GlassIntensity.soft,
      borderRadius: AppRadius.mdAll,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          onPressed: onPressed ?? () {
            if (context.canPop()) {
              context.pop();
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
          tooltip: 'Back',
        ),
      ),
    );
  }
}
