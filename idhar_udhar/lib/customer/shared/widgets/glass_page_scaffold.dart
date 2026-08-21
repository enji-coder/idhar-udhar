import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/theme.dart';
import 'package:idhar_udhar/customer/core/utils/responsive.dart';
import 'package:idhar_udhar/customer/core/widgets/ambient_glow.dart';
import 'package:idhar_udhar/customer/core/widgets/cinematic_background.dart';
import 'package:idhar_udhar/customer/core/widgets/safe_asset_image.dart';

/// Shared full-bleed premium background for customer screens.
class GlassPageScaffold extends StatelessWidget {
  const GlassPageScaffold({
    required this.child,
    super.key,
    this.useAuthCanvas = true,
    this.cinematic = false,
    this.padding,
    this.bottom,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget child;
  /// Kept for call-site compatibility; all canvases use the approved sunset theme.
  final bool useAuthCanvas;
  /// Kept for call-site compatibility; all canvases use the approved sunset theme.
  final bool cinematic;
  final EdgeInsetsGeometry? padding;
  final Widget? bottom;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final double hPad = Responsive.horizontalPadding(context);

    final Widget body = Column(
      children: [
        Expanded(
          child: Padding(
            padding: padding ??
                EdgeInsets.fromLTRB(
                  hPad,
                  AppSpacing.md,
                  hPad,
                  AppSpacing.md,
                ),
            child: child,
          ),
        ),
        if (bottom != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              hPad,
              0,
              hPad,
              viewInsets.bottom > 0 ? AppSpacing.sm : AppSpacing.lg,
            ),
            child: bottom,
          ),
      ],
    );

    final Widget canvasChild = SafeArea(child: body);

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: Colors.transparent,
      // Attached reference: warm sunset glass canvas on all customer screens.
      body: CinematicBackground(safeArea: false, child: canvasChild),
    );
  }
}

/// Compact 3D hero used on several booking screens.
class FloatingAssetHero extends StatelessWidget {
  const FloatingAssetHero({
    required this.path,
    super.key,
    this.height = 110,
  });

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AmbientGlow(
      diameter: height * 1.4,
      opacity: 0.22,
      child: SafeAssetImage(
        path: path,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
