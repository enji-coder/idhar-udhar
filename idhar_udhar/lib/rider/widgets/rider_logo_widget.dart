import 'package:flutter/material.dart';

import '../assets/rider_assets.dart';

/// Official IDHAR UDHAR logo — no redesign / no color changes.
class RiderLogoWidget extends StatelessWidget {
  const RiderLogoWidget({
    super.key,
    this.height = 72,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      RiderAssets.logo,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
