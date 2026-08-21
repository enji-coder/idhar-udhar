import 'package:flutter/material.dart';

import '../constants/asset_paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import 'ambient_glow.dart';
import 'safe_asset_image.dart';

/// Approved reference canvas — warm sunset cityscape + soft ambient light.
///
/// Matches the attached glassmorphism theme (not navy cinematic).
class CinematicBackground extends StatelessWidget {
  const CinematicBackground({
    required this.child,
    super.key,
    this.safeArea = true,
    this.imagePath = AssetPaths.loginBackground,
  });

  final Widget child;
  final bool safeArea;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Photographic / illustrated sunset base (falls back to gradient).
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppGradients.referenceSunset),
        ),
        Positioned.fill(
          child: SafeAssetImage(
            path: imagePath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            fallback: const SizedBox.shrink(),
          ),
        ),
        // Soft warm wash so glass stays readable.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.sunsetGold.withValues(alpha: 0.18),
                    AppColors.softPeach.withValues(alpha: 0.22),
                    AppColors.sunsetLavender.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -size.height * 0.08,
          right: -size.width * 0.18,
          child: AmbientGlow(
            diameter: size.shortestSide * 0.75,
            color: AppColors.orangeSoft,
            opacity: 0.28,
          ),
        ),
        Positioned(
          bottom: -size.height * 0.06,
          left: -size.width * 0.2,
          child: AmbientGlow(
            diameter: size.shortestSide * 0.65,
            color: AppColors.sunsetLavender,
            opacity: 0.22,
          ),
        ),
        Positioned(
          top: size.height * 0.42,
          left: size.width * 0.25,
          child: AmbientGlow(
            diameter: size.shortestSide * 0.35,
            color: AppColors.peach,
            opacity: 0.2,
          ),
        ),
        safeArea ? SafeArea(child: child) : child,
      ],
    );
  }
}
