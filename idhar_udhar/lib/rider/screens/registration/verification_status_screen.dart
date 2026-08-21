import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/dummy_rider_data.dart';
import '../../data/local/rider_permissions.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_secondary_button.dart';
import '../../widgets/rider_verification_timeline.dart';

class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  State<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  bool _complete = false;

  @override
  Widget build(BuildContext context) {
    final steps = _complete
        ? DummyRiderData.verificationComplete
        : DummyRiderData.verificationInProgress;

    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_complete) ...[
            RiderSecondaryButton(
              label: 'Simulate verification complete',
              onPressed: () => setState(() => _complete = true),
            ),
            const SizedBox(height: RiderSpacing.md),
          ],
          RiderPrimaryButton(
            label: _complete ? 'Continue' : 'Continue anyway (demo)',
            onPressed: () async {
              final granted = await RiderPermissions.areAllRequiredGranted();
              if (!context.mounted) return;
              if (granted) {
                await context.push(RiderRoutes.registrationComplete);
              } else {
                await context.push(RiderRoutes.permissionSetup, extra: 'complete');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _complete
                  ? Icons.verified_rounded
                  : Icons.hourglass_top_rounded,
              size: 56,
              color: _complete ? RiderColors.success : RiderColors.primary,
            ),
            const SizedBox(height: RiderSpacing.lg),
            Text(
              _complete ? 'Verification Complete' : 'Verification in progress',
              style: RiderTextStyles.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              _complete
                  ? 'Your Rider account is ready.'
                  : 'Your documents are being reviewed.',
              style: RiderTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderVerificationTimeline(steps: steps),
            if (!_complete) ...[
              const SizedBox(height: RiderSpacing.lg),
              RiderGlassCard(
                padding: const EdgeInsets.all(RiderSpacing.lg),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: RiderColors.primary,
                    ),
                    const SizedBox(width: RiderSpacing.md),
                    Expanded(
                      child: Text(
                        'This usually takes a few minutes. You can continue setting up permissions.',
                        style: RiderTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
