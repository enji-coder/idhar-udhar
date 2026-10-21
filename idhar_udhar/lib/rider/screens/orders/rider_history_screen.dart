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
      padding: EdgeInsets.zero,
      appBar: AppBar(
        backgroundColor: RiderColors.background,
        foregroundColor: RiderColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Trip History',
          style: RiderTextStyles.title.copyWith(fontWeight: FontWeight.w700),
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip History',
            style: RiderTextStyles.heading.copyWith(
              fontSize: 22,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Completed and cancelled trips',
            style: RiderTextStyles.caption.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final RiderHistoryFilter filter in _filters) ...[
                _FilterPill(
                  label: _filterLabel(filter),
                  selected: _filter == filter,
                  onTap: () => setState(() => _filter = filter),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (widget.snapshot.failedDetails > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  itemCount: visible.length + (widget.onLoadMore == null ? 0 : 1),
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 8),
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
      color: selected ? RiderColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? RiderColors.primary : const Color(0xFFD5E4E2),
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
    final bool finished = record.canonicalStatus == 'DELIVERED' ||
        record.canonicalStatus == 'RESEND_COMPLETED';
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: const Color(0x140F3D3E),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3EEEC)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0C0F3D3E),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      id,
                      style: RiderTextStyles.title.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (status.isNotEmpty)
                    _StatusPill(
                      label: status,
                      cancelled: cancelled,
                      finished: finished,
                    ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: RiderColors.hint,
                  ),
                ],
              ),
              if (record.when != null) ...[
                const SizedBox(height: 2),
                Text(
                  stamp.format(record.when!.toLocal()),
                  style: RiderTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              _RouteSummary(pickup: record.pickup, drop: record.drop),
              _CardFooter(record: record, currency: currency),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.pickup, required this.drop});

  final String? pickup;
  final String? drop;

  @override
  Widget build(BuildContext context) {
    final String from = (pickup ?? '').trim();
    final String to = (drop ?? '').trim();
    if (from.isEmpty && to.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        if (from.isNotEmpty)
          _StopLine(
            color: RiderColors.primary,
            text: from,
            drawTail: to.isNotEmpty,
          ),
        if (to.isNotEmpty)
          _StopLine(
            color: const Color(0xFFE08A12),
            text: to,
            drawTail: false,
          ),
      ],
    );
  }
}

class _StopLine extends StatelessWidget {
  const _StopLine({
    required this.color,
    required this.text,
    required this.drawTail,
  });

  final Color color;
  final String text;
  final bool drawTail;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (drawTail)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(top: 2, bottom: 2),
                      color: const Color(0xFFD5E4E2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: drawTail ? 2 : 0),
              child: Text(
                text,
                style: RiderTextStyles.bodyMedium.copyWith(
                  fontSize: 13,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.record, required this.currency});

  final RiderHistoryRecord record;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final double? fare = record.tripFare;
    final double? earning = record.riderAmount;
    final String method = (record.paymentLabel ?? '').trim();
    if (fare == null && earning == null && method.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool onlineOnly =
        method.contains('Online') && !method.contains('Cash');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (method.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: onlineOnly
                    ? const Color(0xFFE7F4F7)
                    : const Color(0xFFFFF6E8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    onlineOnly
                        ? Icons.account_balance_wallet_outlined
                        : Icons.payments_outlined,
                    size: 13,
                    color: onlineOnly
                        ? RiderColors.primary
                        : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    method,
                    style: RiderTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onlineOnly
                          ? RiderColors.primary
                          : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (fare != null)
                Text(
                  currency.format(fare),
                  style: RiderTextStyles.title.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (earning != null)
                Text(
                  'Earning ${currency.format(earning)}',
                  style: RiderTextStyles.caption,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.cancelled,
    required this.finished,
  });

  final String label;
  final bool cancelled;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final Color background = cancelled
        ? const Color(0xFFFDECEC)
        : finished
            ? const Color(0xFFE7F8EE)
            : const Color(0xFFE7F4F7);
    final Color foreground = cancelled
        ? RiderColors.error
        : finished
            ? const Color(0xFF157A3A)
            : RiderColors.primary;
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
