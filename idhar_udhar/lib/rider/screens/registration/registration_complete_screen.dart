import 'package:flutter/material.dart';

import '../../assets/rider_assets.dart';
import '../../data/local/rider_permissions.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';

class RegistrationCompleteScreen extends StatelessWidget {
  const RegistrationCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      bottom: RiderPrimaryButton(
        label: 'Go to Dashboard',
        onPressed: () => riderEnterAfterAuth(context),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final artH = (constraints.maxHeight * 0.22).clamp(120.0, 180.0);
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  const SizedBox(height: RiderSpacing.xl),
                  const Icon(
                    Icons.celebration_rounded,
                    size: 48,
                    color: RiderColors.primary,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  Text(
                    "You're Ready to Ride!",
                    style: RiderTextStyles.display.copyWith(fontSize: 26),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: RiderSpacing.sm),
                  Text(
                    'Your rider account is fully set up.',
                    style: RiderTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: RiderSpacing.xl),
                  Image.asset(
                    RiderAssets.deliveryScooter,
                    height: artH,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: RiderSpacing.xl),
                  const RiderGlassCard(
                    child: Column(
                      children: [
                        _ReadyRow(label: 'Profile completed'),
                        SizedBox(height: RiderSpacing.md),
                        _ReadyRow(label: 'Vehicle verified'),
                        SizedBox(height: RiderSpacing.md),
                        _ReadyRow(label: 'Documents verified'),
                        SizedBox(height: RiderSpacing.md),
                        _ReadyRow(label: 'Account activated'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReadyRow extends StatelessWidget {
  const _ReadyRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: RiderColors.success),
        const SizedBox(width: RiderSpacing.md),
        Expanded(child: Text(label, style: RiderTextStyles.bodyMedium)),
      ],
    );
  }
}
