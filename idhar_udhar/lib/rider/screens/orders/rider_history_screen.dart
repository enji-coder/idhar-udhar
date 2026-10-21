import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:intl/intl.dart';

import '../../features/orders/rider_order_board.dart';
import '../../features/orders/rider_order_board_providers.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_scaffold.dart';

class RiderHistoryScreen extends ConsumerWidget {
  const RiderHistoryScreen({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RiderHistorySnapshot> history =
        ref.watch(riderOrderHistoryProvider);
    final Widget body = history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) {
        final String message = error is ApiException
            ? error.message
            : 'Trip history could not be loaded.';
        return _HistoryNotice(
          title: 'Trip history could not be loaded',
          body: message,
          onRetry: () => ref.invalidate(riderOrderHistoryProvider),
        );
      },
      data: (RiderHistorySnapshot snapshot) => _HistoryList(
        snapshot: snapshot,
        onRefresh: () async {
          ref.invalidate(riderOrderHistoryProvider);
          await ref.read(riderOrderHistoryProvider.future);
        },
        onLoadMore: snapshot.hasMore
            ? () {
                ref.read(riderHistoryLimitProvider.notifier).state =
                    ref.read(riderHistoryLimitProvider) + riderHistoryPageSize;
              }
            : null,
      ),
    );
    if (!showAppBar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TripHeader(),
          Expanded(child: body),
        ],
      );
    }
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
      ),
      body: body,
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RiderColors.textPrimary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          RiderSpacing.screenH,
          RiderSpacing.md,
          RiderSpacing.screenH,
          RiderSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip History',
              style: RiderTextStyles.heading.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              'Completed and cancelled trips',
              style: RiderTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatefulWidget {
  const _HistoryList({
    required this.snapshot,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final RiderHistorySnapshot snapshot;
  final Future<void> Function() onRefresh;
  final VoidCallback? onLoadMore;

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  RiderHistoryFilter _filter = RiderHistoryFilter.all;

  static const List<RiderHistoryFilter> _filters = <RiderHistoryFilter>[
    RiderHistoryFilter.all,
    RiderHistoryFilter.completed,
    RiderHistoryFilter.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    final List<RiderHistoryRecord> visible = <RiderHistoryRecord>[
      for (final RiderHistoryRecord record in widget.snapshot.records)
        if (historyRecordMatches(record, _filter)) record,
    ];
    final NumberFormat currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final DateFormat stamp = DateFormat('d MMM yyyy · h:mm a');
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
          child: Row(
            children: [
              for (final RiderHistoryFilter filter in _filters) ...[
                _FilterPill(
                  label: _filterLabel(filter),
                  selected: _filter == filter,
                  onTap: () => setState(() => _filter = filter),
                ),
                const SizedBox(width: RiderSpacing.sm),
              ],
            ],
          ),
        ),
        if (widget.snapshot.failedDetails > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RiderSpacing.screenH),
            child: Text(
              'Some trip details could not be loaded.',
              style: RiderTextStyles.caption,
            ),
          ),
        Expanded(
          child: visible.isEmpty
              ? _HistoryNotice(
                  title: widget.snapshot.records.isEmpty
                      ? 'No trips yet'
                      : 'No trips for this filter',
                  body: widget.snapshot.records.isEmpty
                      ? 'Completed and cancelled trips appear here.'
                      : 'Try another filter.',
                  onRetry: null,
                )
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    RiderSpacing.screenH,
                    RiderSpacing.sm,
                    RiderSpacing.screenH,
                    RiderSpacing.xl,
                  ),
                  itemCount: visible.length + (widget.onLoadMore == null ? 0 : 1),
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: RiderSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    if (index >= visible.length) {
                      return TextButton(
                        onPressed: widget.onLoadMore,
                        child: const Text('Load more'),
                      );
                    }
                    final RiderHistoryRecord record = visible[index];
                    return _TripCard(
                      record: record,
                      currency: currency,
                      stamp: stamp,
                      onTap: () {
                        final String id = record.orderId.trim();
                        if (id.isEmpty) {
                          return;
                        }
                        context.push('${RiderRoutes.pastOrder}?id=$id');
                      },
                    );
                  },
                ),
                ),
        ),
      ],
    );
  }

  String _filterLabel(RiderHistoryFilter filter) {
    switch (filter) {
      case RiderHistoryFilter.all:
        return 'All';
      case RiderHistoryFilter.completed:
        return 'Completed';
      case RiderHistoryFilter.cancelled:
        return 'Cancelled';
      case RiderHistoryFilter.running:
        return 'Active';
    }
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? RiderColors.textPrimary : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? RiderColors.textPrimary : const Color(0xFFD5E4E2),
            ),
          ),
          child: Text(
            label,
            style: RiderTextStyles.caption.copyWith(
              color: selected ? Colors.white : RiderColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.record,
    required this.currency,
    required this.stamp,
    required this.onTap,
  });

  final RiderHistoryRecord record;
  final NumberFormat currency;
  final DateFormat stamp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String status = historyStatusLabel(record.canonicalStatus);
    final bool cancelled = record.canonicalStatus == 'CANCELLED';
    final String id = record.displayId.trim().isEmpty
        ? record.orderId
        : record.displayId.trim();
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(RiderSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3EEEC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      id,
                      style: RiderTextStyles.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (status.isNotEmpty) _StatusPill(label: status, cancelled: cancelled),
                ],
              ),
              const SizedBox(height: RiderSpacing.sm),
              _PlaceRow(
                icon: Icons.storefront_outlined,
                text: record.pickup,
              ),
              const SizedBox(height: RiderSpacing.xs),
              _PlaceRow(
                icon: Icons.location_on_outlined,
                text: record.drop,
              ),
              const SizedBox(height: RiderSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: record.when == null
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: RiderColors.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  stamp.format(record.when!.toLocal()),
                                  style: RiderTextStyles.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: RiderSpacing.sm),
                  _MoneyColumn(record: record, currency: currency),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.icon, required this.text});

  final IconData icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final String shown = (text ?? '').trim();
    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: RiderColors.textPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            shown,
            style: RiderTextStyles.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MoneyColumn extends StatelessWidget {
  const _MoneyColumn({required this.record, required this.currency});

  final RiderHistoryRecord record;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final double? fare = record.tripFare;
    final double? earning = record.riderAmount;
    final String? method = record.paymentLabel?.trim();
    if (fare == null && earning == null && (method == null || method.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (fare != null)
          Text(
            currency.format(fare),
            style: RiderTextStyles.title,
          ),
        if (earning != null)
          Text(
            'Earning ${currency.format(earning)}',
            style: RiderTextStyles.caption,
          ),
        if (method != null && method.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                method.contains('Online') && !method.contains('Cash')
                    ? Icons.account_balance_wallet_outlined
                    : Icons.payments_outlined,
                size: 14,
                color: RiderColors.textPrimary,
              ),
              const SizedBox(width: 4),
              Text(method, style: RiderTextStyles.caption),
            ],
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.cancelled});

  final String label;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final Color background =
        cancelled ? const Color(0xFFFDECEC) : const Color(0xFFE7F8EE);
    final Color foreground = cancelled ? RiderColors.error : const Color(0xFF157A3A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: RiderTextStyles.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistoryNotice extends StatelessWidget {
  const _HistoryNotice({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RiderSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: RiderTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: RiderSpacing.sm),
            Text(body, style: RiderTextStyles.body, textAlign: TextAlign.center),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
