import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'ambient_glow.dart';
import 'safe_asset_image.dart';

/// 3D asset that floats in-scene with contact shadow + soft ambient glow.
///
/// Avoids generic rectangular drop-shadows behind PNGs.
class FloatingAsset extends StatelessWidget {
  const FloatingAsset({
    required this.path,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallback,
    this.showGlow = true,
    this.glowColor = AppColors.orange,
    this.glowOpacity = 0.22,
    this.bob = 0,
    this.alignment = Alignment.center,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;
  final bool showGlow;
  final Color glowColor;
  final double glowOpacity;
  final double bob;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final double w = width ?? 160;
    final double h = height ?? w * 0.72;

    return SizedBox(
      width: w,
      height: h + 18,
      child: Stack(
        alignment: alignment,
        clipBehavior: Clip.none,
        children: [
          if (showGlow)
            Positioned(
              left: w * 0.12,
              right: w * 0.12,
              bottom: 4,
              child: AmbientGlow(
                color: glowColor,
                diameter: w * 0.72,
                opacity: glowOpacity,
              ),
            ),
          // Soft elliptical contact shadow (not a rectangle).
          Positioned(
            left: w * 0.18,
            right: w * 0.18,
            bottom: 6,
            child: IgnorePointer(
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withOpacity(0.22),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                  gradient: RadialGradient(
                    colors: [
                      AppColors.navy.withOpacity(0.28),
                      AppColors.navy.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 12,
            child: Transform.translate(
              offset: Offset(0, bob),
              child: SafeAssetImage(
                path: path,
                fit: fit,
                fallback: fallback ??
                    Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.orange,
                      size: w * 0.28,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
