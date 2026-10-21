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
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_scaffold.dart';

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
    final NumberFormat currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final DateFormat dateFormat = DateFormat('d MMM yyyy');
    final DateFormat timeFormat = DateFormat('h:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showAppBar)
          Material(
            color: RiderColors.textPrimary,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                RiderSpacing.screenH,
                RiderSpacing.md,
                RiderSpacing.screenH,
                RiderSpacing.md,
              ),
              child: Text(
                'Ledger Board',
                style: RiderTextStyles.heading.copyWith(color: Colors.white),
              ),
            ),
          ),
        Expanded(
          child: RiderScaffold(
            appBar: showAppBar
                ? AppBar(
                    title: const Text('Ledger Board'),
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
          onRetry: () => ref.invalidate(riderWalletLedgerProvider),
        ),
        data: (List<RiderWalletLedgerEntry> entries) {
          if (entries.isEmpty) {
            return const _LedgerMessage(
              title: 'No ledger entries yet',
              body: 'Wallet credits and debits will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(riderWalletLedgerProvider);
              await ref.read(riderWalletLedgerProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: RiderSpacing.md),
              itemBuilder: (BuildContext context, int index) {
                final RiderWalletLedgerEntry entry = entries[index];
                final DateTime? created = entry.createdAt?.toLocal();
                final String when = created == null
                    ? ''
                    : '${dateFormat.format(created)} · ${timeFormat.format(created)}';
                return RiderGlassCard(
                  child: InkWell(
                    onTap: () => _showEntry(context, entry, currency, when),
                    borderRadius: RiderRadius.xlAll,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 64),
                      child: Row(
                        children: [
                          Icon(
                            entry.isCredit
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
                            color: entry.isCredit
                                ? RiderColors.success
                                : RiderColors.error,
                          ),
                          const SizedBox(width: RiderSpacing.md),
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
                                      ? (entry.isCredit ? 'Credit' : 'Debit')
                                      : '$when · ${entry.isCredit ? 'Credit' : 'Debit'}',
                                  style: RiderTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            currency.format(entry.amount),
                            style: RiderTextStyles.bodyMedium.copyWith(
                              color: entry.isCredit
                                  ? RiderColors.success
                                  : RiderColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
    NumberFormat currency,
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
              Text(currency.format(entry.amount), style: RiderTextStyles.title),
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
