import 'package:flutter/material.dart';

/// Typed hero wrappers for shared-element transitions between screens.
class AppHero extends StatelessWidget {
  const AppHero({
    required this.tag,
    required this.child,
    super.key,
    this.createRectTween,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
  });

  /// Brand logo hero used across splash and auth.
  factory AppHero.logo({
    required Widget child,
    Key? key,
  }) {
    return AppHero(
      key: key,
      tag: 'iu_brand_logo',
      child: child,
    );
  }

  /// Vehicle image hero for selection → confirmation.
  factory AppHero.vehicle({
    required String vehicleId,
    required Widget child,
    Key? key,
  }) {
    return AppHero(
      key: key,
      tag: 'iu_vehicle_$vehicleId',
      child: child,
    );
  }

  final Object tag;
  final Widget child;
  final CreateRectTween? createRectTween;
  final HeroFlightShuttleBuilder? flightShuttleBuilder;
  final HeroPlaceholderBuilder? placeholderBuilder;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      createRectTween: createRectTween,
      flightShuttleBuilder: flightShuttleBuilder,
      placeholderBuilder: placeholderBuilder,
      child: child,
    );
  }
}
