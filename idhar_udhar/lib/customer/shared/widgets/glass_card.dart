import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/glass_effect.dart';
import 'package:idhar_udhar/customer/core/widgets/glass_card.dart' as core;

import 'glass_container.dart';

/// Large frosted content panel for forms and sheets.
///
/// Delegates to core [GlassCard] to avoid duplicate glass implementations.
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
    this.enableBlur = true,
    this.showBorder = true,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final GlassIntensity intensity;
  final bool enableBlur;
  final bool showBorder;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return core.GlassCard(
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      borderRadius: borderRadius,
      intensity: intensity,
      enableBlur: enableBlur,
      showBorder: showBorder,
      showShadow: showShadow,
      child: child,
    );
  }
}

/// Alias note: prefer [GlassContainer] when you need raw blur/opacity knobs.
typedef SharedGlassSurface = GlassContainer;
