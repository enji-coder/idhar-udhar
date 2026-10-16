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
    this.voiceMuted = false,
    this.onToggleVoice,
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
  final bool voiceMuted;
  final VoidCallback? onToggleVoice;

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
                if (onToggleVoice != null) ...[
                  const SizedBox(height: RiderSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _VoiceGuidanceButton(
                      muted: voiceMuted,
                      onPressed: onToggleVoice!,
                    ),
                  ),
                ],
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
                if (secondaryLabel != null && onSecondary != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
                    child: _ReceiverUnavailablePrompt(
                      semanticsLabel: secondaryLabel!,
                      onViewDetails: onSecondary!,
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

class _VoiceGuidanceButton extends StatelessWidget {
  const _VoiceGuidanceButton({
    required this.muted,
    required this.onPressed,
  });

  final bool muted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String tooltip =
        muted ? 'Unmute voice guidance' : 'Mute voice guidance';
    return Semantics(
      button: true,
      label: tooltip,
      toggled: muted,
      child: Material(
        color: muted ? Colors.white : RiderColors.primary,
        elevation: 3,
        shape: CircleBorder(
          side: BorderSide(
            color: muted ? RiderColors.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: muted ? RiderColors.primary : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Soft delivery-status prompt (not an error banner) above the primary CTA.
class _ReceiverUnavailablePrompt extends StatelessWidget {
  const _ReceiverUnavailablePrompt({
    required this.semanticsLabel,
    required this.onViewDetails,
  });

  final String semanticsLabel;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: RiderColors.surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onViewDetails,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFD7EEF5),
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: RiderColors.primary,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: RiderColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: RiderColors.surface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.help_outline_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receiver not available?',
                        style: RiderTextStyles.title.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'View contact details & take action',
                        style: RiderTextStyles.caption.copyWith(
                          color: RiderColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: FilledButton(
                    onPressed: onViewDetails,
                    style: FilledButton.styleFrom(
                      backgroundColor: RiderColors.primary,
                      foregroundColor: RiderColors.textOnPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: RiderTextStyles.bodyMedium.copyWith(
                        color: RiderColors.textOnPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View Details'),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
