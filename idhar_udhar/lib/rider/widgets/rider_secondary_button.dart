import 'package:flutter/material.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';

/// Outlined / soft secondary action for Rider flows.
class RiderSecondaryButton extends StatelessWidget {
  const RiderSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.enabled = true,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && onPressed != null;
    final Color borderColor =
        destructive ? RiderColors.error : RiderColors.primary;
    final Color textColor =
        destructive ? RiderColors.error : RiderColors.primary;

    return Opacity(
      opacity: active ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: RiderRadius.pillAll,
          onTap: active ? onPressed : null,
          child: Ink(
            height: RiderSpacing.buttonHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: RiderColors.surfaceGlass,
              borderRadius: RiderRadius.pillAll,
              border: Border.all(color: borderColor.withValues(alpha: 0.55)),
            ),
            child: Center(
              child: Text(
                label,
                style: RiderTextStyles.button.copyWith(color: textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
