import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_radius.dart';
import 'package:idhar_udhar/customer/core/theme/app_shadows.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/glass_effect.dart';

/// Single reusable glassmorphism container for the entire app.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.blurSigma,
    this.opacity,
    this.borderColor,
    this.backgroundColor,
    this.intensity = GlassIntensity.medium,
    this.depth = GlassDepthLevel.normal,
    this.showBorder = true,
    this.showShadow = true,
    this.enableBlur = true,
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
  final double? blurSigma;
  final double? opacity;
  final Color? borderColor;
  final Color? backgroundColor;
  final GlassIntensity intensity;
  final GlassDepthLevel depth;
  final bool showBorder;
  final bool showShadow;
  final bool enableBlur;
  final bool showAmbientGlow;
  final Color? ambientColor;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: GlassEffect(
        width: width,
        height: height,
        intensity: hero ? GlassIntensity.heavy : intensity,
        depth: hero ? GlassDepthLevel.hero : depth,
        borderRadius: borderRadius ?? AppRadius.xlAll,
        padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
        blurSigma: blurSigma,
        opacity: opacity,
        borderColor: borderColor,
        backgroundColor: backgroundColor,
        showBorder: showBorder,
        showShadow: showShadow,
        enableBlur: enableBlur,
        showInnerHighlight: true,
        showAmbientGlow: showAmbientGlow || hero,
        ambientColor: ambientColor,
        child: child,
      ),
    );
  }
}
