import 'package:flutter/material.dart';

import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import 'vehicle_marker.dart';

class TripNavigationView extends StatelessWidget {
  const TripNavigationView({
    required this.map,
    required this.vehicleName,
    required this.instruction,
    required this.maneuverDistance,
    required this.remainingLabel,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onMenu,
    this.primaryEnabled = true,
    this.secondaryLabel,
    this.onSecondary,
    this.statusMessage,
    this.onRetryRoute,
    super.key,
  });

  final Widget map;
  final String vehicleName;
  final String instruction;
  final String maneuverDistance;
  final String remainingLabel;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback onMenu;
  final bool primaryEnabled;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? statusMessage;
  final VoidCallback? onRetryRoute;

  @override
  Widget build(BuildContext context) {
    final RiderVehicleMarker marker = vehicleMarkerFor(vehicleName);
    final String markerName = vehicleMarkerLabel(marker, vehicleName);
    return Stack(
      children: [
        Positioned.fill(child: map),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(RiderSpacing.md),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Material(
                        color: RiderColors.surface,
                        elevation: 3,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(RiderSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                instruction,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: RiderTextStyles.title,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$maneuverDistance · $remainingLabel',
                                style: RiderTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: RiderSpacing.sm),
                    Material(
                      color: RiderColors.surface,
                      elevation: 3,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Order details',
                        onPressed: onMenu,
                        icon: const Icon(Icons.menu_rounded),
                        color: RiderColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    key: ValueKey<String>('vehicle-marker-${marker.name}'),
                    color: RiderColors.surface,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            vehicleMarkerIcon(marker),
                            color: RiderColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(markerName, style: RiderTextStyles.caption),
                        ],
                      ),
                    ),
                  ),
                ),
                if (statusMessage != null && statusMessage!.isNotEmpty) ...[
                  const SizedBox(height: RiderSpacing.sm),
                  Material(
                    color: RiderColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(RiderSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusMessage!,
                            style: RiderTextStyles.caption,
                          ),
                          if (onRetryRoute != null)
                            TextButton(
                              onPressed: onRetryRoute,
                              child: const Text('Try route again'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: RiderSpacing.sm),
                if (secondaryLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RiderColors.error,
                          side: const BorderSide(color: RiderColors.error),
                        ),
                        child: Text(secondaryLabel!),
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: primaryEnabled ? onPrimary : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: RiderColors.primary,
                      foregroundColor: RiderColors.textOnPrimary,
                      disabledBackgroundColor:
                          RiderColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      textStyle: RiderTextStyles.button.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
