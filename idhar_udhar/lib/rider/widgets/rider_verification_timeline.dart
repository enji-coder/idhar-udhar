import 'package:flutter/material.dart';

import '../data/models/rider_earnings.dart';
import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';
import 'rider_glass_card.dart';

class RiderVerificationTimeline extends StatelessWidget {
  const RiderVerificationTimeline({
    required this.steps,
    super.key,
  });

  final List<VerificationStep> steps;

  @override
  Widget build(BuildContext context) {
    return RiderGlassCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _StepRow(step: steps[i]),
            if (i < steps.length - 1)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Container(
                    width: 2,
                    height: 18,
                    color: RiderColors.border,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final VerificationStep step;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String semantics;
    switch (step.state) {
      case VerificationStepState.done:
        icon = Icons.check_circle_rounded;
        color = RiderColors.success;
        semantics = 'Completed';
      case VerificationStepState.active:
        icon = Icons.radio_button_checked_rounded;
        color = RiderColors.primary;
        semantics = 'In progress';
      case VerificationStepState.pending:
        icon = Icons.radio_button_unchecked_rounded;
        color = RiderColors.hint;
        semantics = 'Pending';
    }

    return Semantics(
      label: '${step.title}, $semantics',
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: RiderSpacing.md),
          Expanded(
            child: Text(
              step.title,
              style: RiderTextStyles.bodyMedium.copyWith(
                color: step.state == VerificationStepState.pending
                    ? RiderColors.textSecondary
                    : RiderColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RiderDeliveryStepper extends StatelessWidget {
  const RiderDeliveryStepper({
    required this.current,
    required this.statuses,
    super.key,
  });

  final int current;
  final List<String> statuses;

  @override
  Widget build(BuildContext context) {
    return RiderGlassCard(
      child: Column(
        children: [
          for (var i = 0; i < statuses.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(
                      i < current
                          ? Icons.check_circle_rounded
                          : i == current
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                      color: i <= current
                          ? RiderColors.primary
                          : RiderColors.hint,
                    ),
                    if (i < statuses.length - 1)
                      Container(
                        width: 2,
                        height: 22,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: i < current
                            ? RiderColors.primary.withValues(alpha: 0.45)
                            : RiderColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: RiderSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      statuses[i],
                      style: RiderTextStyles.bodyMedium.copyWith(
                        color: i <= current
                            ? RiderColors.textPrimary
                            : RiderColors.textSecondary,
                        fontWeight:
                            i == current ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
