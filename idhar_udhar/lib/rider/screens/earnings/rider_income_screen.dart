import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../state/rider_session.dart';
import '../../data/dummy/dummy_rider_repository.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_section_header.dart';
import '../../widgets/rider_stat_card.dart';

class RiderIncomeScreen extends ConsumerWidget {
  const RiderIncomeScreen({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!showAppBar) ...[
            Text('Earnings', style: RiderTextStyles.heading),
            const SizedBox(height: RiderSpacing.md),
          ],
          const TabBar(
            labelColor: RiderColors.primary,
            unselectedLabelColor: RiderColors.textSecondary,
            indicatorColor: RiderColors.primary,
            tabs: [
              Tab(text: 'Daily'),
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _DailyIncome(),
                _PeriodIncome(weekly: true),
                _PeriodIncome(weekly: false),
              ],
            ),
          ),
        ],
      ),
    );

    if (!showAppBar) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          RiderSpacing.screenH,
          RiderSpacing.md,
          RiderSpacing.screenH,
          0,
        ),
        child: body,
      );
    }

    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Income summary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        RiderSpacing.screenH,
        RiderSpacing.sm,
        RiderSpacing.screenH,
        RiderSpacing.lg,
      ),
      body: body,
    );
  }
}

class _DailyIncome extends ConsumerWidget {
  const _DailyIncome();

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(riderApiEarningsProvider).value ??
        ref.watch(dummyRiderRepositoryProvider).getEarnings();
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return ListView(
      padding: const EdgeInsets.only(top: RiderSpacing.lg),
      children: [
        RiderGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RiderSectionHeader(title: 'Daily summary'),
              const SizedBox(height: RiderSpacing.lg),
              Text('Deliveries', style: RiderTextStyles.caption),
              Text(
                '${earnings.completedOrders}',
                style: RiderTextStyles.heading,
              ),
              const SizedBox(height: RiderSpacing.md),
              Text('Earnings', style: RiderTextStyles.caption),
              Text(
                currency.format(earnings.todayAmount),
                style: RiderTextStyles.heading,
              ),
              const SizedBox(height: RiderSpacing.md),
              Text('Time spent', style: RiderTextStyles.caption),
              Text(
                _formatDuration(earnings.onlineDuration),
                style: RiderTextStyles.heading,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodIncome extends ConsumerWidget {
  const _PeriodIncome({required this.weekly});

  final bool weekly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(riderApiEarningsProvider).value ??
        ref.watch(dummyRiderRepositoryProvider).getEarnings();
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final deliveries =
        weekly ? earnings.weeklyDeliveries : earnings.monthlyDeliveries;
    final amount = weekly ? earnings.weeklyEarnings : earnings.monthlyEarnings;

    return ListView(
      padding: const EdgeInsets.only(top: RiderSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: RiderStatCard(
                label: 'Total deliveries',
                value: '$deliveries',
                icon: Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: RiderSpacing.md),
            Expanded(
              child: RiderStatCard(
                label: 'Total earnings',
                value: currency.format(amount),
                icon: Icons.payments_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
