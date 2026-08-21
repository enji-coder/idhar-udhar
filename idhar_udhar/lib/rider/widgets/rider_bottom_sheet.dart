import 'package:flutter/material.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';

Future<T?> showRiderBottomSheet<T>({
  required BuildContext context,
  required String title,
  required List<RiderSheetAction<T>> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RiderSpacing.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RiderColors.surface,
              borderRadius: RiderRadius.xlAll,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: RiderColors.primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                RiderSpacing.xl,
                RiderSpacing.xl,
                RiderSpacing.xl,
                RiderSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: RiderColors.border,
                        borderRadius: RiderRadius.pillAll,
                      ),
                    ),
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  Text(title, style: RiderTextStyles.title),
                  const SizedBox(height: RiderSpacing.lg),
                  for (final action in actions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(action.icon, color: RiderColors.primary),
                      title: Text(
                        action.label,
                        style: RiderTextStyles.bodyMedium,
                      ),
                      onTap: () => Navigator.of(context).pop(action.value),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class RiderSheetAction<T> {
  const RiderSheetAction({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final T value;
}
