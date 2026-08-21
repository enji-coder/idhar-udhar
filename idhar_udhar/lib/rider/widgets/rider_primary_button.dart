import 'package:flutter/material.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';

/// Primary gradient pill button for Rider flows.
class RiderPrimaryButton extends StatelessWidget {
  const RiderPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && onPressed != null;
    return Opacity(
      opacity: active ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RiderColors.primaryGradient,
          borderRadius: RiderRadius.pillAll,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: RiderColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: RiderRadius.pillAll,
            onTap: active ? onPressed : null,
            child: SizedBox(
              height: RiderSpacing.buttonHeight,
              width: double.infinity,
              child: Center(
                child: Text(label, style: RiderTextStyles.button),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
