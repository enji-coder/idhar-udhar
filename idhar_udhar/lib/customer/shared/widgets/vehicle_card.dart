import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/widgets/vehicle_card.dart' as core;

/// Selectable vehicle category card.
///
/// Delegates to core [VehicleCard] — no duplicate selection UI.
class VehicleCard extends StatelessWidget {
  const VehicleCard({
    required this.title,
    required this.selected,
    required this.onTap,
    super.key,
    this.subtitle,
    this.image,
    this.imagePath,
    this.vehicleId,
    this.width = 112,
    this.height = 148,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? image;
  final String? imagePath;
  final String? vehicleId;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return core.VehicleCard(
      title: title,
      subtitle: subtitle,
      selected: selected,
      onTap: onTap,
      image: image,
      imagePath: imagePath,
      vehicleId: vehicleId,
      width: width,
      height: height,
    );
  }
}
