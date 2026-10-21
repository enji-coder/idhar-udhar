import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';

/// Orders tab entries. History and the ledger stay separate.
class RiderOrdersHub extends StatelessWidget {
  const RiderOrdersHub({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(RiderSpacing.screenH),
      children: [
        Text('Orders', style: RiderTextStyles.heading),
        const SizedBox(height: RiderSpacing.sm),
        Text(
          'Delivery history and wallet ledger are separate records.',
          style: RiderTextStyles.caption,
        ),
        const SizedBox(height: RiderSpacing.xl),
        _HubCard(
          icon: Icons.history_rounded,
          title: 'Order History',
          subtitle: 'Past deliveries, status, pickup, drop, and fare',
          onTap: () => context.push(RiderRoutes.history),
        ),
        const SizedBox(height: RiderSpacing.md),
        _HubCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Ledger Board',
          subtitle: 'Wallet credits and debits from the ledger',
          onTap: () => context.push(RiderRoutes.ledger),
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RiderGlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: RiderRadius.xlAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Row(
            children: [
              Icon(icon, color: RiderColors.primary),
              const SizedBox(width: RiderSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: RiderTextStyles.title),
                    const SizedBox(height: RiderSpacing.xs),
                    Text(subtitle, style: RiderTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
