import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_gradients.dart';
import 'app_radius.dart';
import 'app_shadows.dart';

export 'app_shadows.dart' show GlassDepthLevel;

/// Intensity presets for frosted glass surfaces.
enum GlassIntensity {
  soft,
  medium,
  heavy,
}

/// Multi-layer premium glass: glow → blur → gradient fill → rim → sheen → content.
class GlassEffect extends StatelessWidget {
  const GlassEffect({
    required this.child,
    super.key,
    this.intensity = GlassIntensity.medium,
    this.depth = GlassDepthLevel.normal,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
    this.blurSigma,
    this.opacity,
    this.showBorder = true,
    this.showShadow = true,
    this.enableBlur = true,
    this.showInnerHighlight = true,
    this.showAmbientGlow = false,
    this.ambientColor,
    this.borderColor,
    this.borderWidth = 1.15,
    this.backgroundColor,
    this.fillGradient,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final GlassIntensity intensity;
  final GlassDepthLevel depth;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final double? blurSigma;
  final double? opacity;
  final bool showBorder;
  final bool showShadow;
  final bool enableBlur;
  final bool showInnerHighlight;
  final bool showAmbientGlow;
  final Color? ambientColor;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final Gradient? fillGradient;
  final Clip clipBehavior;

  double get _resolvedBlur {
    if (blurSigma != null) {
      return blurSigma!;
    }
    switch (intensity) {
      case GlassIntensity.soft:
        return 14;
      case GlassIntensity.medium:
        return 22;
      case GlassIntensity.heavy:
        return 28;
    }
  }

  Gradient get _resolvedGradient {
    if (fillGradient != null) {
      return fillGradient!;
    }
    if (backgroundColor != null) {
      return LinearGradient(
        colors: [backgroundColor!, backgroundColor!],
      );
    }
    if (opacity != null) {
      final Color c = AppColors.white.withValues(alpha: opacity!);
      return LinearGradient(colors: [c, c.withValues(alpha: opacity! * 0.7)]);
    }
    switch (depth) {
      case GlassDepthLevel.subtle:
        return AppGradients.glassFill;
      case GlassDepthLevel.normal:
        return AppGradients.glassFill;
      case GlassDepthLevel.hero:
        return AppGradients.glassFillHero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? AppRadius.xlAll;
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final bool useBlur = enableBlur && !reduceMotion;
    final List<BoxShadow> shadows =
        showShadow ? AppShadows.forDepth(depth) : const <BoxShadow>[];

    final Widget glassBody = ClipRRect(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: Stack(
        children: [
          if (useBlur)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _resolvedBlur,
                  sigmaY: _resolvedBlur,
                ),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: useBlur
                    ? _resolvedGradient
                    : LinearGradient(
                        colors: [
                          AppColors.cream.withValues(alpha: 0.92),
                          AppColors.warmWhite.withValues(alpha: 0.88),
                        ],
                      ),
                borderRadius: radius,
              ),
            ),
          ),
          if (showInnerHighlight)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 28,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: radius.topLeft,
                      topRight: radius.topRight,
                    ),
                    gradient: AppGradients.glassSheen,
                  ),
                ),
              ),
            ),
          if (showBorder)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      width: borderWidth,
                      color: borderColor ??
                          AppColors.white.withValues(
                            alpha: depth == GlassDepthLevel.hero ? 0.55 : 0.42,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );

    Widget layered = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: glassBody,
    );

    if (width != null || height != null) {
      layered = SizedBox(width: width, height: height, child: layered);
    }

    if (!showAmbientGlow) {
      return layered;
    }

    final Color glow = ambientColor ?? AppColors.orange;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.22),
                    blurRadius: 36,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
        ),
        layered,
      ],
    );
  }
}
