import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft atmospheric radial glow — never neon.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({
    super.key,
    this.color = AppColors.orange,
    this.diameter,
    this.opacity = 0.28,
    this.child,
    this.alignment = Alignment.center,
  });

  const AmbientGlow.orange({
    super.key,
    this.diameter,
    this.opacity = 0.28,
    this.child,
    this.alignment = Alignment.center,
  }) : color = AppColors.orange;

  const AmbientGlow.navy({
    super.key,
    this.diameter,
    this.opacity = 0.28,
    this.child,
    this.alignment = Alignment.center,
  }) : color = AppColors.navy;

  final Color color;
  final double? diameter;
  final double opacity;
  final Widget? child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final double size =
        diameter ?? MediaQuery.sizeOf(context).shortestSide * 0.55;

    return Stack(
      alignment: alignment,
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: opacity),
                  color.withValues(alpha: opacity * 0.35),
                  color.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

/// Soft elliptical contact shadow under floating 3D assets.
class AssetContactShadow extends StatelessWidget {
  const AssetContactShadow({
    required this.child,
    super.key,
    this.widthFactor = 0.55,
    this.height = 14,
    this.glow = true,
  });

  final Widget child;
  final double widthFactor;
  final double height;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (glow)
          AmbientGlow(
            diameter: 120,
            opacity: 0.18,
            child: child,
          )
        else
          child,
        Transform.translate(
          offset: const Offset(0, -6),
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  colors: [
                    AppColors.navy.withValues(alpha: 0.22),
                    AppColors.navy.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
