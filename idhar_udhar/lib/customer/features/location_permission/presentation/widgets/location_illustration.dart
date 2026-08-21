import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/safe_asset_image.dart';

/// Location education illustration — prefers production WebP; painted fallback.
class LocationIllustration extends StatelessWidget {
  const LocationIllustration({
    super.key,
    this.size = 220,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SafeAssetImage(
        path: AssetPaths.locationIllustration,
        fit: BoxFit.contain,
        fallback: CustomPaint(painter: _LocationPainter()),
      ),
    );
  }
}

class _LocationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      center.translate(0, size.height * 0.08),
      size.width * 0.42,
      Paint()..color = AppColors.softPeach.withOpacity(0.85),
    );

    final Paint building = Paint()..color = AppColors.navy.withOpacity(0.85);
    final List<Rect> blocks = [
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.42,
        size.width * 0.16,
        size.height * 0.32,
      ),
      Rect.fromLTWH(
        size.width * 0.38,
        size.height * 0.32,
        size.width * 0.18,
        size.height * 0.42,
      ),
      Rect.fromLTWH(
        size.width * 0.6,
        size.height * 0.48,
        size.width * 0.2,
        size.height * 0.26,
      ),
    ];
    for (final Rect rect in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.xs)),
        building,
      );
    }

    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.22),
      size.width * 0.06,
      Paint()..color = AppColors.sunsetGold,
    );

    final Path pin = Path()
      ..moveTo(center.dx, center.dy - size.height * 0.05)
      ..quadraticBezierTo(
        center.dx + size.width * 0.14,
        center.dy + size.height * 0.02,
        center.dx,
        center.dy + size.height * 0.22,
      )
      ..quadraticBezierTo(
        center.dx - size.width * 0.14,
        center.dy + size.height * 0.02,
        center.dx,
        center.dy - size.height * 0.05,
      );
    canvas.drawPath(pin, Paint()..color = AppColors.orange);
    canvas.drawCircle(
      Offset(center.dx, center.dy + size.height * 0.02),
      size.width * 0.045,
      Paint()..color = AppColors.white,
    );

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + size.height * 0.28),
        width: size.width * 0.28,
        height: size.height * 0.08,
      ),
      0,
      math.pi * 2,
      false,
      Paint()..color = AppColors.navy.withOpacity(0.12),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
