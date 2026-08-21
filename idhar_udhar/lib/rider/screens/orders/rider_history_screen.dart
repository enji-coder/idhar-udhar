import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/models/recent_activity.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_section_header.dart';

class RiderHistoryScreen extends ConsumerWidget {
  const RiderHistoryScreen({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  RiderChipTone _tone(String status) {
    switch (status) {
      case 'Accepted':
      case 'Completed':
        return RiderChipTone.success;
      case 'Rejected by Rider':
      case 'Rejected by Client':
      case 'Cancelled':
        return RiderChipTone.error;
      default:
        return RiderChipTone.neutral;
    }
  }

  IconData _icon(String status) {
    switch (status) {
      case 'Accepted':
      case 'Completed':
        return Icons.check_circle_outline_rounded;
      case 'Rejected by Rider':
        return Icons.highlight_off_rounded;
      case 'Rejected by Client':
        return Icons.person_off_outlined;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(riderDeliveryHistoryProvider);
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final body = items.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(RiderSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: RiderColors.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  Text('No delivery history yet', style: RiderTextStyles.title),
                  const SizedBox(height: RiderSpacing.sm),
                  Text(
                    'Accepted and rejected requests will appear here.',
                    style: RiderTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : ListView.separated(
            padding: showAppBar
                ? EdgeInsets.zero
                : const EdgeInsets.all(RiderSpacing.screenH),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: RiderSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return _HistoryCard(
                item: item,
                currency: currency,
                tone: _tone(item.status),
                icon: _icon(item.status),
              );
            },
          );

    if (!showAppBar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RiderSpacing.screenH,
              RiderSpacing.md,
              RiderSpacing.screenH,
              RiderSpacing.sm,
            ),
            child: Text('History', style: RiderTextStyles.heading),
          ),
          Expanded(child: body),
        ],
      );
    }

    return RiderScaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: body,
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.currency,
    required this.tone,
    required this.icon,
  });

  final RecentActivityItem item;
  final NumberFormat currency;
  final RiderChipTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return RiderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order #${item.orderId}',
                  style: RiderTextStyles.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: RiderSpacing.sm),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: RiderStatusChip(
                    label: item.status,
                    tone: tone,
                    icon: icon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RiderSpacing.sm),
          Text(
            item.routeLabel,
            style: RiderTextStyles.caption,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: RiderSpacing.sm),
          Row(
            children: [
              if (item.timeLabel.isNotEmpty)
                Expanded(
                  child: Text(item.timeLabel, style: RiderTextStyles.caption),
                )
              else
                const Spacer(),
              Text(
                currency.format(item.amount),
                style: RiderTextStyles.bodyMedium.copyWith(
                  color: RiderColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
