import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';
import 'package:idhar_udhar/shared/format/inr_format.dart';
import 'package:intl/intl.dart';

import '../../features/orders/rider_order_board.dart';
import '../../features/orders/rider_order_board_providers.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_scaffold.dart';
import 'rider_trip_statement.dart';

final riderLedgerTripsProvider = FutureProvider<List<RiderEarningRow>>((ref) {
  return ref.read(walletApiProvider).earnings();
});

class RiderLedgerScreen extends ConsumerWidget {
  const RiderLedgerScreen({
    super.key,
    this.showAppBar = true,
  });

  /// False when this screen is the Ledger bottom-navigation tab.
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RiderWalletLedgerEntry>> ledger =
        ref.watch(riderWalletLedgerProvider);
    final AsyncValue<List<RiderEarningRow>> trips =
        ref.watch(riderLedgerTripsProvider);
    final DateFormat dateFormat = DateFormat('d MMM yyyy');
    final DateFormat timeFormat = DateFormat('h:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showAppBar) const _LedgerTitle(),
        Expanded(
          child: RiderScaffold(
            padding: EdgeInsets.zero,
            appBar: showAppBar
                ? AppBar(
                    backgroundColor: RiderColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    centerTitle: true,
                    title: Text(
                      'Ledger Board',
                      style: RiderTextStyles.title.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
                    ),
                  )
                : null,
            body: ledger.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => _LedgerMessage(
                title: 'Ledger could not be loaded',
                body: error is ApiException
                    ? error.message
                    : 'Check the connection and try again.',
                onRetry: () {
                  ref.invalidate(riderWalletLedgerProvider);
                  ref.invalidate(riderLedgerTripsProvider);
                },
              ),
              data: (List<RiderWalletLedgerEntry> entries) {
                final List<RiderEarningRow> tripRows =
                    trips.value ?? const <RiderEarningRow>[];
                if (entries.isEmpty && tripRows.isEmpty && trips.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (entries.isEmpty && tripRows.isEmpty) {
                  return const _LedgerMessage(
                    title: 'No ledger entries yet',
                    body: 'Trip earnings and wallet credits will appear here.',
                  );
                }
                final double received = entries
                    .where((RiderWalletLedgerEntry entry) => entry.isCredit)
                    .fold<double>(0, (double sum, RiderWalletLedgerEntry entry) {
                  return sum + entry.amount;
                });
                final double paidOut = entries
                    .where((RiderWalletLedgerEntry entry) => !entry.isCredit)
                    .fold<double>(0, (double sum, RiderWalletLedgerEntry entry) {
                  return sum + entry.amount;
                });
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(riderWalletLedgerProvider);
                    ref.invalidate(riderLedgerTripsProvider);
                    await ref.read(riderWalletLedgerProvider.future);
                    await ref.read(riderLedgerTripsProvider.future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (entries.isNotEmpty)
                        RiderStatementCard(
                          icon: Icons.account_balance_rounded,
                          title: 'Ledger',
                          child: Column(
                            children: [
                              RiderStatementRow(
                                icon: Icons.south_west_rounded,
                                label: 'Received',
                                value: formatInr(received),
                                valueColor: RiderColors.success,
                                emphasize: true,
                              ),
                              RiderStatementRow(
                                icon: Icons.north_east_rounded,
                                label: 'Paid out',
                                value: formatInr(paidOut),
                                valueColor: RiderColors.error,
                                emphasize: true,
                              ),
                            ],
                          ),
                        ),
                      if (tripRows.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        RiderStatementCard(
                          icon: Icons.receipt_long_rounded,
                          title: 'Trips',
                          child: Column(
                            children: [
                              for (final RiderEarningRow trip
                                  in tripRows.reversed)
                                _TripRow(
                                  trip: trip,
                                  onTap: () => context.push(
                                    '${RiderRoutes.pastOrder}?id=${trip.orderId}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      RiderStatementCard(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Wallet',
                        child: entries.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('No wallet credits or debits yet.'),
                              )
                            : Column(
                                children: [
                                  for (final RiderWalletLedgerEntry entry
                                      in entries)
                                    _WalletRow(
                                      entry: entry,
                                      dateFormat: dateFormat,
                                      timeFormat: timeFormat,
                                      onTap: () => _showEntry(
                                        context,
                                        entry,
                                        entry.createdAt?.toLocal() == null
                                            ? ''
                                            : '${dateFormat.format(entry.createdAt!.toLocal())} · ${timeFormat.format(entry.createdAt!.toLocal())}',
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showEntry(
    BuildContext context,
    RiderWalletLedgerEntry entry,
    String when,
  ) {
    final String? orderId = entry.relatedOrderId;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RiderColors.surface,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            RiderSpacing.lg,
            0,
            RiderSpacing.lg,
            RiderSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ledger entry', style: RiderTextStyles.title),
              const SizedBox(height: RiderSpacing.md),
              Text(
                ledgerEntryTitle(entry.entryType),
                style: RiderTextStyles.bodyMedium,
              ),
              Text(
                entry.isCredit ? 'Credit' : 'Debit',
                style: RiderTextStyles.caption,
              ),
              const SizedBox(height: RiderSpacing.sm),
              Text(formatInr(entry.amount), style: RiderTextStyles.title),
              if (when.isNotEmpty) ...[
                const SizedBox(height: RiderSpacing.sm),
                Text(when, style: RiderTextStyles.caption),
              ],
              const SizedBox(height: RiderSpacing.sm),
              Text('Reference ${entry.id}', style: RiderTextStyles.caption),
              if (entry.relatedPaymentTransactionId != null) ...[
                const SizedBox(height: RiderSpacing.xs),
                Text(
                  'Payment ${entry.relatedPaymentTransactionId}',
                  style: RiderTextStyles.caption,
                ),
              ],
              if (orderId != null) ...[
                const SizedBox(height: RiderSpacing.xs),
                Text('Order $orderId', style: RiderTextStyles.caption),
                const SizedBox(height: RiderSpacing.lg),
                FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.push('${RiderRoutes.pastOrder}?id=$orderId');
                  },
                  child: const Text('View order'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LedgerTitle extends StatelessWidget {
  const _LedgerTitle();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RiderColors.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Text(
          'Ledger Board',
          style: RiderTextStyles.heading.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip, required this.onTap});

  final RiderEarningRow trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String title =
        trip.displayId.trim().isEmpty ? trip.orderId : trip.displayId.trim();
    final String? outcome = earningSettlementLabel(trip.settlementStatus);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: RiderColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 15,
                color: RiderColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: RiderTextStyles.bodyMedium),
                  Text(
                    outcome ?? 'Earning',
                    style: RiderTextStyles.caption,
                  ),
                ],
              ),
            ),
            Text(
              formatInr(trip.riderAmount),
              style: RiderTextStyles.bodyMedium.copyWith(
                color: RiderColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: RiderColors.hint),
          ],
        ),
      ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({
    required this.entry,
    required this.dateFormat,
    required this.timeFormat,
    required this.onTap,
  });

  final RiderWalletLedgerEntry entry;
  final DateFormat dateFormat;
  final DateFormat timeFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime? created = entry.createdAt?.toLocal();
    final String when = created == null
        ? ''
        : '${dateFormat.format(created)} · ${timeFormat.format(created)}';
    final bool credit = entry.isCredit;
    final Color tone = credit ? RiderColors.success : RiderColors.error;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                credit ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 15,
                color: tone,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ledgerEntryTitle(entry.entryType),
                    style: RiderTextStyles.bodyMedium,
                  ),
                  Text(
                    when.isEmpty
                        ? (credit ? 'Credit' : 'Debit')
                        : '$when · ${credit ? 'Credit' : 'Debit'}',
                    style: RiderTextStyles.caption,
                  ),
                ],
              ),
            ),
            Text(
              formatInr(entry.amount),
              style: RiderTextStyles.bodyMedium.copyWith(
                color: tone,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerMessage extends StatelessWidget {
  const _LedgerMessage({
    required this.title,
    required this.body,
    this.onRetry,
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
            Text(
              title,
              style: RiderTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              body,
              style: RiderTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
