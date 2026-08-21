import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import 'ambient_glow.dart';

/// Full-bleed warm premium canvas for Splash / Login / OTP.
///
/// Layered ambient orbs — never flat white.
class AuthPremiumBackground extends StatelessWidget {
  const AuthPremiumBackground({
    required this.child,
    super.key,
    this.safeArea = true,
  });

  final Widget child;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.referenceSunset),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -size.height * 0.1,
            right: -size.width * 0.2,
            child: AmbientGlow(
              diameter: size.shortestSide * 0.7,
              color: AppColors.orangeSoft,
              opacity: 0.34,
            ),
          ),
          Positioned(
            bottom: size.height * 0.08,
            left: -size.width * 0.22,
            child: AmbientGlow(
              diameter: size.shortestSide * 0.58,
              color: AppColors.navy,
              opacity: 0.14,
            ),
          ),
          Positioned(
            top: size.height * 0.4,
            right: -size.width * 0.08,
            child: AmbientGlow(
              diameter: size.shortestSide * 0.38,
              color: AppColors.peach,
              opacity: 0.4,
            ),
          ),
          Positioned(
            bottom: size.height * 0.35,
            right: size.width * 0.15,
            child: AmbientGlow(
              diameter: size.shortestSide * 0.25,
              color: AppColors.sunsetGold,
              opacity: 0.18,
            ),
          ),
          // Soft top light wash
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      AppColors.white.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          safeArea ? SafeArea(child: child) : child,
        ],
      ),
    );
  }
}
