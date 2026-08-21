import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../assets/rider_assets.dart';
import '../../data/dummy/dummy_rider_data.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';

class RegistrationWelcomeScreen extends StatelessWidget {
  const RegistrationWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      bottom: RiderPrimaryButton(
        label: 'Get Started',
        onPressed: () => context.push(RiderRoutes.mobileVerification),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double artH = (constraints.maxHeight * 0.28).clamp(140.0, 220.0);
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome, Rider',
                    style: RiderTextStyles.display,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: RiderSpacing.sm),
                  Text.rich(
                    TextSpan(
                      style: RiderTextStyles.body,
                      children: [
                        const TextSpan(text: 'Become a part of '),
                        TextSpan(
                          text: 'Idhar Udhar',
                          style: RiderTextStyles.bodyMedium.copyWith(
                            color: RiderColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: RiderSpacing.xl),
                  Center(
                    child: Image.asset(
                      RiderAssets.deliveryScooter,
                      height: artH,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: RiderSpacing.xl),
                  RiderGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Why partner with us', style: RiderTextStyles.title),
                        const SizedBox(height: RiderSpacing.lg),
                        for (final benefit in DummyRiderData.welcomeBenefits) ...[
                          _BenefitRow(text: benefit),
                          if (benefit != DummyRiderData.welcomeBenefits.last)
                            const SizedBox(height: RiderSpacing.md),
                        ],
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

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: RiderColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: RiderColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: RiderSpacing.md),
        Expanded(child: Text(text, style: RiderTextStyles.bodyMedium)),
      ],
    );
  }
}
