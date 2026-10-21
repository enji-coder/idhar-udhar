import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/models/rider_order.dart';
import '../../features/orders/external_navigation.dart';
import '../../features/orders/rider_order_board.dart';
import '../../features/orders/rider_order_board_providers.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_section_header.dart';

class RiderActiveDeliverySection extends ConsumerStatefulWidget {
  const RiderActiveDeliverySection({super.key});

  @override
  ConsumerState<RiderActiveDeliverySection> createState() =>
      _RiderActiveDeliverySectionState();
}

class _RiderActiveDeliverySectionState
    extends ConsumerState<RiderActiveDeliverySection> {
  String? _openingId;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RiderRunningBoard> board =
        ref.watch(riderRunningDeliveriesProvider);
    ref.listen<AsyncValue<RiderRunningBoard>>(
      riderRunningDeliveriesProvider,
      (
        AsyncValue<RiderRunningBoard>? previous,
        AsyncValue<RiderRunningBoard> next,
      ) {
        final RiderRunningBoard? value = next.value;
        if (value == null || !value.clearLocalOrder) {
          return;
        }
        if (ref.read(activeOrderProvider) == null) {
          return;
        }
        ref.read(activeOrderProvider.notifier).state = null;
        ref.read(deliveryStatusProvider.notifier).state =
            DeliveryLifecycleStatus.accepted;
      },
    );
    return board.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: RiderSpacing.md),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (Object error, StackTrace stackTrace) => _message(
        'Active deliveries could not be loaded.',
        onRetry: () => refreshRiderRunningDeliveries(ref),
      ),
      data: (RiderRunningBoard value) {
        if (value.errorMessage != null && value.running.isEmpty) {
          return _message(
            value.errorMessage!,
            onRetry: () => refreshRiderRunningDeliveries(ref),
          );
        }
        if (value.running.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: RiderSpacing.md),
          child: Column(
            children: [
              for (final RiderTrackedDelivery item in value.running) ...[
                _ActiveDeliveryCard(
                  item: item,
                  busy: _openingId ==
                      (item.order.backendOrderId ?? item.order.id),
                  onContinue: () => _open(item),
                ),
                const SizedBox(height: RiderSpacing.md),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(RiderTrackedDelivery item) async {
    final String tapped = (item.order.backendOrderId ?? '').trim();
    if (tapped.isEmpty || _openingId != null) {
      return;
    }
    setState(() => _openingId = tapped);
    final RiderOrder? local = ref.read(activeOrderProvider);
    final String localId = (local?.backendOrderId ?? '').trim();
    final RunningDeliveryOpenPlan plan = planRunningDeliveryOpen(
      tappedOrderId: tapped,
      localOrderId: localId.isEmpty ? null : localId,
      localStillRunning: local != null &&
          localDeliveryStillRunning(ref.read(deliveryStatusProvider)),
      hasRiderPhase: item.fromLocalOnly ||
          riderCanonicalHasDeliveryPhase(item.canonicalStatus),
    );
    if (!plan.readOnly && plan.adopt) {
      ref.read(activeOrderProvider.notifier).state = item.order;
      final DeliveryLifecycleStatus? phase =
          OrderMapper.tryRiderLifecycle(item.canonicalStatus);
      if (phase != null) {
        ref.read(deliveryStatusProvider.notifier).state = phase;
      }
    }
    if (!plan.readOnly) {
      RiderNavSession.requestRestore();
    }
    if (!mounted) {
      return;
    }
    await context.push(plan.route);
    if (mounted) {
      setState(() => _openingId = null);
    }
  }

  Widget _message(String message, {required VoidCallback onRetry}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RiderSpacing.md),
      child: RiderGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: RiderTextStyles.caption),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({
    required this.item,
    required this.busy,
    required this.onContinue,
  });

  final RiderTrackedDelivery item;
  final bool busy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final RiderOrder order = item.order;
    final String status =
        item.fromLocalOnly ? '' : historyStatusLabel(item.canonicalStatus);
    final bool resumePhase = item.fromLocalOnly ||
        riderCanonicalHasDeliveryPhase(item.canonicalStatus);
    final String title = order.crn == null || order.crn!.trim().isEmpty
        ? 'Order ${order.id}'
        : 'Order ${order.id} · CRN ${order.crn}';
    return RiderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_rounded,
                color: RiderColors.primary,
              ),
              const SizedBox(width: RiderSpacing.sm),
              Expanded(
                child: Text('Running Order', style: RiderTextStyles.title),
              ),
              if (status.isNotEmpty)
                Flexible(
                  child: RiderStatusChip(
                    label: status,
                    tone: RiderChipTone.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: RiderSpacing.sm),
          Text(title, style: RiderTextStyles.bodyMedium),
          const SizedBox(height: RiderSpacing.sm),
          Text('Pickup', style: RiderTextStyles.caption),
          Text(order.pickup, style: RiderTextStyles.bodyMedium),
          const SizedBox(height: RiderSpacing.sm),
          Text('Drop', style: RiderTextStyles.caption),
          Text(order.drop, style: RiderTextStyles.bodyMedium),
          const SizedBox(height: RiderSpacing.md),
          FilledButton(
            onPressed: busy ? null : onContinue,
            child: Text(
              busy
                  ? 'Opening…'
                  : resumePhase
                      ? 'Continue Delivery'
                      : 'View order',
            ),
          ),
        ],
      ),
    );
  }
}
