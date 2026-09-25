import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/rider_assets.dart';
import '../../data/local/rider_permissions.dart';
import '../../state/rider_session.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';

class RegistrationCompleteScreen extends ConsumerWidget {
  const RegistrationCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool approved = ref.watch(riderSessionProvider).isApproved;
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
                    approved ? "You're Ready to Ride!" : 'Registration submitted',
                    style: RiderTextStyles.display.copyWith(fontSize: 26),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: RiderSpacing.sm),
                  Text(
                    approved
                        ? 'Your rider account is approved.'
                        : 'Verification is still pending. Deliveries stay locked until approval.',
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
                  RiderGlassCard(
                    child: Column(
                      children: [
                        _ReadyRow(
                          label: approved
                              ? 'Account approved'
                              : 'Waiting for approval',
                          done: approved,
                        ),
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
  const _ReadyRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
          color: done ? RiderColors.success : RiderColors.primary,
        ),
        const SizedBox(width: RiderSpacing.md),
        Expanded(child: Text(label, style: RiderTextStyles.bodyMedium)),
      ],
    );
  }
}
