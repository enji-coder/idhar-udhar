import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/rider_permissions.dart';
import '../../data/models/rider_earnings.dart';
import '../../state/rider_session.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_verification_timeline.dart';

class VerificationStatusScreen extends ConsumerStatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  ConsumerState<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState
    extends ConsumerState<VerificationStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(riderSessionProvider.notifier).refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final RiderSessionState session = ref.watch(riderSessionProvider);
    final String approval = session.approvalStatus ?? 'PENDING';
    final String kyc = session.onboardingKycStatus ?? 'PENDING';
    final bool approved = session.isApproved;
    final bool rejected = approval == 'REJECTED' || kyc == 'REJECTED';

    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: RiderPrimaryButton(
        label: 'Continue',
        onPressed: () => riderEnterAfterAuth(context),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              approved
                  ? Icons.verified_rounded
                  : rejected
                      ? Icons.error_outline_rounded
                      : Icons.hourglass_top_rounded,
              size: 56,
              color: approved
                  ? RiderColors.success
                  : rejected
                      ? RiderColors.error
                      : RiderColors.primary,
            ),
            const SizedBox(height: RiderSpacing.lg),
            Text(
              approved
                  ? 'Verification complete'
                  : rejected
                      ? 'Verification rejected'
                      : 'Verification in progress',
              style: RiderTextStyles.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              approved
                  ? 'Your rider account is approved.'
                  : rejected
                      ? 'This account was not approved. You can still open the app.'
                      : 'Your account is waiting for review. Deliveries stay locked until approval.',
              style: RiderTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderVerificationTimeline(steps: _steps(kyc, approval)),
            const SizedBox(height: RiderSpacing.lg),
            RiderGlassCard(
              padding: const EdgeInsets.all(RiderSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Approval status: $approval', style: RiderTextStyles.bodyMedium),
                  const SizedBox(height: RiderSpacing.sm),
                  Text('KYC status: $kyc', style: RiderTextStyles.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<VerificationStep> _steps(String kyc, String approval) {
    if (approval == 'APPROVED') {
      return const <VerificationStep>[
        VerificationStep(
          title: 'Review complete',
          state: VerificationStepState.done,
        ),
        VerificationStep(
          title: 'Account activation',
          state: VerificationStepState.done,
        ),
      ];
    }
    if (approval == 'REJECTED' || kyc == 'REJECTED') {
      return const <VerificationStep>[
        VerificationStep(
          title: 'Review',
          state: VerificationStepState.active,
        ),
        VerificationStep(
          title: 'Account activation',
          state: VerificationStepState.pending,
        ),
      ];
    }
    if (kyc == 'SUBMITTED' || kyc == 'APPROVED') {
      return const <VerificationStep>[
        VerificationStep(
          title: 'Documents submitted',
          state: VerificationStepState.done,
        ),
        VerificationStep(
          title: 'Account activation',
          state: VerificationStepState.active,
        ),
      ];
    }
    return const <VerificationStep>[
      VerificationStep(
        title: 'Waiting for review',
        state: VerificationStepState.active,
      ),
      VerificationStep(
        title: 'Account activation',
        state: VerificationStepState.pending,
      ),
    ];
  }
}
