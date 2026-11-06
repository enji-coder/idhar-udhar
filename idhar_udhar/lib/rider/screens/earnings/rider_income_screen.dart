import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/profiles_api.dart';
import 'package:idhar_udhar/shared/format/inr_format.dart';
import 'package:intl/intl.dart';

import '../../data/models/rider_earnings.dart';
import '../../rider_features.dart';
import '../../state/rider_session.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings =
        ref.watch(riderApiEarningsProvider).value ?? RiderEarnings.empty;
    final currency = inrFormat;

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
              if (RiderFeatures.onlineTimeEnabled) const _DailyOnlineTime(),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyOnlineTime extends ConsumerStatefulWidget {
  const _DailyOnlineTime();

  @override
  ConsumerState<_DailyOnlineTime> createState() => _DailyOnlineTimeState();
}

class _DailyOnlineTimeState extends ConsumerState<_DailyOnlineTime> {
  String? _date;
  String? _today;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RiderOnlineDay> online =
        ref.watch(riderOnlineTimeProvider(_date));
    final DateFormat dayLabel = DateFormat('d MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
              const SizedBox(height: RiderSpacing.md),
              Text('Online time', style: RiderTextStyles.caption),
              const SizedBox(height: RiderSpacing.xs),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous day',
                    onPressed: () => _shiftDay(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      online.maybeWhen(
                        data: (day) => day.date.isEmpty
                            ? 'Today'
                            : dayLabel.format(_calendarDate(day.date)),
                        orElse: () => _date ?? 'Today',
                      ),
                      textAlign: TextAlign.center,
                      style: RiderTextStyles.bodyMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    onPressed: _date == null ? null : () => _shiftDay(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              online.when(
                loading: () => Text('Loading…', style: RiderTextStyles.body),
                error: (_, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Online time could not be loaded.',
                      style: RiderTextStyles.body.copyWith(color: RiderColors.error),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(riderOnlineTimeProvider(_date)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                data: (day) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatOnlineSeconds(day.totalSeconds),
                      style: RiderTextStyles.heading,
                    ),
                    if (day.hasActiveShift) ...[
                      const SizedBox(height: RiderSpacing.sm),
                      Text(
                        'This shift ${formatOnlineSeconds(day.activeElapsedSeconds!)}',
                        style: RiderTextStyles.bodyMedium.copyWith(
                          color: RiderColors.success,
                        ),
                      ),
                    ],
                    const SizedBox(height: RiderSpacing.md),
                    Text('Shifts', style: RiderTextStyles.caption),
                    const SizedBox(height: RiderSpacing.sm),
                    if (day.shifts.isEmpty)
                      Text(
                        'No online time recorded for this day.',
                        style: RiderTextStyles.body,
                      )
                    else
                      for (final RiderOnlineShift shift in day.shifts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            _shiftLine(shift),
                            style: RiderTextStyles.body,
                          ),
                        ),
                  ],
                ),
              ),
      ],
    );
  }

  void _shiftDay(int days) {
    final RiderOnlineDay? loaded =
        ref.read(riderOnlineTimeProvider(_date)).asData?.value;
    final String anchor = _date ?? loaded?.date ?? '';
    if (anchor.isEmpty) {
      return;
    }
    if (_date == null) {
      _today = anchor;
    }
    final DateTime next = _calendarDate(anchor).add(Duration(days: days));
    final String formatted =
        '${next.year.toString().padLeft(4, '0')}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    setState(() {
      final String? today = _today;
      _date = today != null && formatted.compareTo(today) >= 0 ? null : formatted;
    });
  }

  DateTime _calendarDate(String ymd) {
    final List<String> parts = ymd.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  String _shiftLine(RiderOnlineShift shift) {
    final DateFormat clock = DateFormat('h:mm a');
    final String start = shift.startedAt == null
        ? '—'
        : clock.format(shift.startedAt!.toLocal());
    final String end = shift.active
        ? 'Now'
        : shift.endedAt == null
            ? '—'
            : clock.format(shift.endedAt!.toLocal());
    return '$start – $end · ${formatOnlineSeconds(shift.seconds)}';
  }
}

class _PeriodIncome extends ConsumerWidget {
  const _PeriodIncome({required this.weekly});

  final bool weekly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings =
        ref.watch(riderApiEarningsProvider).value ?? RiderEarnings.empty;
    final currency = inrFormat;
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
