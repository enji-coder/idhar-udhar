import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import 'safe_asset_image.dart';

/// Full-screen photographic or asset background with optional scrim.
///
/// Missing [imagePath] assets fall back to the sunset gradient (no crash).
class ScreenBackground extends StatelessWidget {
  const ScreenBackground({
    required this.child,
    super.key,
    this.imagePath,
    this.fit = BoxFit.cover,
    this.overlay,
    this.alignment = Alignment.center,
    this.safeArea = true,
  });

  final Widget child;
  final String? imagePath;
  final BoxFit fit;
  final Color? overlay;
  final Alignment alignment;
  final bool safeArea;

  static const Widget _gradientFallback = DecoratedBox(
    decoration: BoxDecoration(gradient: AppGradients.sunsetBackground),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imagePath != null)
          SafeAssetImage(
            path: imagePath!,
            fit: fit,
            alignment: alignment,
            fallback: _gradientFallback,
          )
        else
          _gradientFallback,
        DecoratedBox(
          decoration: BoxDecoration(
            color: overlay ?? AppColors.scrim.withOpacity(0.15),
          ),
        ),
        safeArea ? SafeArea(child: child) : child,
      ],
    );
  }
}
