import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../animations/hero_animation.dart';
import '../constants/asset_paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'safe_asset_image.dart';

/// Official IDHAR UDHAR logo for splash and auth headers.
///
/// [AssetPaths.logo] already includes the mark **and** “IDHAR UDHAR”
/// wordmark. Default [showWordmark] is `false` to avoid double branding.
/// Pass `showWordmark: true` only when an extra painted wordmark is required.
class TopLogo extends StatelessWidget {
  const TopLogo({
    super.key,
    this.height = AppSpacing.topLogoHeight,
    this.showWordmark = false,
    this.showTagline = false,
    this.stacked = false,
    this.alignment = Alignment.centerLeft,
    this.useHero = true,
  });

  final double height;

  /// Extra painted “IDHAR UDHAR” text beside/below the PNG.
  /// Keep `false` when using the full logo asset (recommended).
  final bool showWordmark;
  final bool showTagline;

  /// When true with [showWordmark], mark sits above the painted wordmark.
  final bool stacked;
  final Alignment alignment;
  final bool useHero;

  @override
  Widget build(BuildContext context) {
    final Widget mark = SafeAssetImage(
      path: AssetPaths.logo,
      height: height,
      fit: BoxFit.contain,
      fallback: _FallbackMark(size: height),
    );

    final Widget logo = useHero ? AppHero.logo(child: mark) : mark;
    final bool centered = alignment == Alignment.center ||
        alignment == Alignment.topCenter ||
        alignment == Alignment.bottomCenter;
    final CrossAxisAlignment cross = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    final TextStyle orangeStyle = AppTextStyles.wordmarkOrange.copyWith(
      fontSize: stacked ? height * 0.28 : height * 0.42,
    );
    final TextStyle navyStyle = AppTextStyles.wordmarkNavy.copyWith(
      fontSize: stacked ? height * 0.28 : height * 0.42,
    );

    final Widget wordmark = RichText(
      textAlign: centered ? TextAlign.center : TextAlign.start,
      text: TextSpan(
        children: [
          TextSpan(text: 'IDHAR ', style: orangeStyle),
          TextSpan(text: 'UDHAR', style: navyStyle),
        ],
      ),
    );

    late final Widget brand;
    if (!showWordmark) {
      brand = logo;
    } else if (stacked) {
      brand = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: cross,
        children: [
          logo,
          const SizedBox(height: AppSpacing.md),
          wordmark,
        ],
      );
    } else {
      brand = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo,
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: wordmark),
        ],
      );
    }

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        brand,
        if (showTagline) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppConfig.tagline,
            style: AppTextStyles.tagline,
            textAlign: centered ? TextAlign.center : TextAlign.start,
          ),
        ],
      ],
    );

    return Align(alignment: alignment, child: content);
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoMarkPainter()),
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint navy = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path u = Path()
      ..moveTo(size.width * 0.22, size.height * 0.28)
      ..lineTo(size.width * 0.22, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.86,
        size.width * 0.5,
        size.height * 0.86,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.86,
        size.width * 0.78,
        size.height * 0.55,
      )
      ..lineTo(size.width * 0.78, size.height * 0.22)
      ..lineTo(size.width * 0.62, size.height * 0.36)
      ..moveTo(size.width * 0.78, size.height * 0.22)
      ..lineTo(size.width * 0.92, size.height * 0.36);

    canvas.drawPath(u, navy);

    final Paint orange = Paint()..color = AppColors.orange;
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.16),
      size.width * 0.1,
      orange,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
