import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPageScaffold(
      child: ListView(
        children: [
          Row(
            children: [
              const IuBackButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Help & Support',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('We’re here for you', style: AppTextStyles.headingS),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Demo support surface. Live chat and ticketing arrive with backend.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...[
            ('How do I book a delivery?', Icons.local_shipping_outlined),
            ('How is fare calculated?', Icons.payments_outlined),
            ('Can I cancel an order?', Icons.cancel_outlined),
            ('Contact support', Icons.support_agent_rounded),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GlassContainer(
                padding: const EdgeInsets.all(AppSpacing.lg),
                borderRadius: AppRadius.lgAll,
                child: Row(
                  children: [
                    Icon(item.$2, color: AppColors.orange),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(item.$1, style: AppTextStyles.bodyMedium),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.navy),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
