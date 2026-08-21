import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/glass_effect.dart';

/// Primary frosted glass panel — floating, translucent, layered.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.intensity = GlassIntensity.medium,
    this.depth = GlassDepthLevel.normal,
    this.blurSigma,
    this.opacity,
    this.borderWidth,
    this.borderColor,
    this.enableBlur = true,
    this.showBorder = true,
    this.showShadow = true,
    this.showAmbientGlow = false,
    this.ambientColor,
    this.hero = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final GlassIntensity intensity;
  final GlassDepthLevel depth;
  final double? blurSigma;
  final double? opacity;
  final double? borderWidth;
  final Color? borderColor;
  final bool enableBlur;
  final bool showBorder;
  final bool showShadow;
  final bool showAmbientGlow;
  final Color? ambientColor;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final GlassDepthLevel resolvedDepth =
        hero ? GlassDepthLevel.hero : depth;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: GlassEffect(
        width: width,
        height: height,
        intensity: hero ? GlassIntensity.heavy : intensity,
        depth: resolvedDepth,
        blurSigma: blurSigma,
        opacity: opacity,
        enableBlur: enableBlur,
        showBorder: showBorder,
        showShadow: showShadow,
        showInnerHighlight: true,
        showAmbientGlow: showAmbientGlow || hero,
        ambientColor: ambientColor,
        borderWidth: borderWidth ?? (hero ? 1.35 : 1.15),
        borderColor: borderColor,
        borderRadius: borderRadius ??
            (hero ? AppRadius.xxlAll : AppRadius.xlAll),
        padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
        child: child,
      ),
    );
  }
}
