import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:intl/intl.dart';

import '../../state/rider_session.dart';
import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/dummy/rider_finance.dart';
import '../../data/models/rider_order.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_secondary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_verification_timeline.dart';

class ActiveDeliveryScreen extends ConsumerWidget {
  const ActiveDeliveryScreen({super.key});

  static const List<DeliveryLifecycleStatus> _happyPath = [
    DeliveryLifecycleStatus.accepted,
    DeliveryLifecycleStatus.goingToPickup,
    DeliveryLifecycleStatus.arrivedAtPickup,
    DeliveryLifecycleStatus.packagePickedUp,
    DeliveryLifecycleStatus.goingToDrop,
    DeliveryLifecycleStatus.delivered,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order =
        ref.watch(activeOrderProvider) ??
        ref.watch(dummyRiderRepositoryProvider).getIncomingOrder();
    final status = ref.watch(deliveryStatusProvider);
    final statuses = _happyPath.map((e) => e.label).toList();
    final int currentIndex = status ==
                DeliveryLifecycleStatus.receiverUnavailable ||
            status == DeliveryLifecycleStatus.parcelAtCompanyOffice
        ? _happyPath.indexOf(DeliveryLifecycleStatus.goingToDrop)
        : _happyPath.indexOf(status);
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final bool done = status == DeliveryLifecycleStatus.delivered ||
        status == DeliveryLifecycleStatus.parcelAtCompanyOffice;
    final CompanyOffice office = PlatformRules.current.office;
    final CancellationQuote riderCancel = CancellationEngine.quote(
      actor: CancellationActor.rider,
      status: _canonicalFor(status),
      config: PlatformRules.current.cancellation,
    );

    return RiderScaffold(
      appBar: AppBar(
        title: Text('Order #${order.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(RiderRoutes.dashboard),
        ),
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == DeliveryLifecycleStatus.goingToDrop)
            Padding(
              padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
              child: RiderSecondaryButton(
                label: 'Receiver Unavailable',
                destructive: true,
                onPressed: () async {
                  final String? orderId = order.backendOrderId;
                  if (orderId != null) {
                    final hops = OrderMapper.riderStatusHops(
                      from: status,
                      to: DeliveryLifecycleStatus.receiverUnavailable,
                    );
                    try {
                      for (final String hop in hops) {
                        await ref.read(riderApiProvider).transitionStatus(
                              orderId: orderId,
                              toStatus: hop,
                            );
                      }
                    } on ApiException catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.message)),
                        );
                      }
                      return;
                    }
                  }
                  ref.read(deliveryStatusProvider.notifier).state =
                      DeliveryLifecycleStatus.receiverUnavailable;
                },
              ),
            ),
          if (!done && riderCancel.allowed)
            Padding(
              padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
              child: RiderSecondaryButton(
                label: riderCancel.fee == 0
                    ? 'Cancel trip (₹0)'
                    : 'Cancel trip (₹${riderCancel.fee.toStringAsFixed(0)})',
                destructive: true,
                onPressed: () {
                  applyRiderEarning(ref, riderCancel.riderAmount);
                  ref.read(activeOrderProvider.notifier).state = null;
                  ref.read(deliveryStatusProvider.notifier).state =
                      DeliveryLifecycleStatus.accepted;
                  context.go(RiderRoutes.dashboard);
                },
              ),
            ),
          if (!done && !riderCancel.allowed)
            Padding(
              padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
              child: Text(
                riderCancel.message,
                textAlign: TextAlign.center,
                style: RiderTextStyles.caption,
              ),
            ),
          RiderPrimaryButton(
            label: done ? 'Back to Dashboard' : status.actionLabel,
            onPressed: () async {
              if (done) {
                ref.read(activeOrderProvider.notifier).state = null;
                ref.read(deliveryStatusProvider.notifier).state =
                    DeliveryLifecycleStatus.accepted;
                context.go(RiderRoutes.dashboard);
                return;
              }
              final next = status.next;
              final String? orderId = order.backendOrderId;
              if (next != null && orderId != null) {
                final hops = OrderMapper.riderStatusHops(from: status, to: next);
                try {
                  for (final String hop in hops) {
                    await ref.read(riderApiProvider).transitionStatus(
                          orderId: orderId,
                          toStatus: hop,
                        );
                  }
                } on ApiException catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.message)),
                    );
                  }
                  return;
                }
              }
              if (next == DeliveryLifecycleStatus.delivered) {
                completeRiderTrip(
                  ref,
                  cashCollected: order.cashCollected,
                  riderAmount: order.riderAmount,
                );
                await ref.read(riderSessionProvider.notifier).refreshWallet();
              }
              if (next != null) {
                ref.read(deliveryStatusProvider.notifier).state = next;
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done ? 'Delivery update' : 'Active delivery',
                    style: RiderTextStyles.title,
                  ),
                  const SizedBox(height: RiderSpacing.sm),
                  Text(
                    '${order.pickup} → ${order.drop}',
                    style: RiderTextStyles.caption,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  Text(
                    currency.format(order.estimatedEarnings),
                    style: RiderTextStyles.heading.copyWith(
                      color: RiderColors.primary,
                    ),
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _moneyRow('Trip Amount', order.tripAmount, currency),
                  _moneyRow(
                    'Customer',
                    order.customerResponsibility,
                    currency,
                  ),
                  _moneyRow(
                    'Receiver',
                    order.receiverResponsibility,
                    currency,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
                    child: Row(
                      children: [
                        Text(
                          'Payment status',
                          style: RiderTextStyles.caption,
                        ),
                        const Spacer(),
                        Text(
                          order.paymentStatusLabel,
                          style: RiderTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RiderSpacing.lg),
            if (status == DeliveryLifecycleStatus.receiverUnavailable ||
                status == DeliveryLifecycleStatus.parcelAtCompanyOffice)
              RiderGlassCard(
                child: Text(
                  'Take the parcel to the IDHAR UDHAR company office:\n${office.address}',
                  style: RiderTextStyles.body,
                ),
              ),
            if (status == DeliveryLifecycleStatus.receiverUnavailable ||
                status == DeliveryLifecycleStatus.parcelAtCompanyOffice)
              const SizedBox(height: RiderSpacing.lg),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _moneyRow('Trip Amount', order.tripAmount, currency),
                  _moneyRow('Rider Amount', order.riderAmount, currency),
                  _moneyRow('IDHAR UDHAR', order.companyShare, currency),
                  if (status ==
                          DeliveryLifecycleStatus.receiverUnavailable ||
                      status ==
                          DeliveryLifecycleStatus.parcelAtCompanyOffice)
                    _moneyRow(
                      'Failed Delivery Office Compensation',
                      order.officeCompensation,
                      currency,
                    ),
                ],
              ),
            ),
            const SizedBox(height: RiderSpacing.lg),
            RiderDeliveryStepper(
              current: currentIndex < 0 ? 0 : currentIndex,
              statuses: statuses,
            ),
            const SizedBox(height: RiderSpacing.lg),
            if (!done)
              RiderGlassCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: RiderColors.primary,
                    ),
                    const SizedBox(width: RiderSpacing.md),
                    Expanded(
                      child: Text(
                        status == DeliveryLifecycleStatus.goingToDrop
                            ? 'Mark delivered, or Receiver Unavailable if nobody is at the drop.'
                            : 'Tap the action below to advance the delivery status.',
                        style: RiderTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static CanonicalOrderStatus _canonicalFor(DeliveryLifecycleStatus status) {
    switch (status) {
      case DeliveryLifecycleStatus.accepted:
        return CanonicalOrderStatus.assigned;
      case DeliveryLifecycleStatus.goingToPickup:
        return CanonicalOrderStatus.enRoutePickup;
      case DeliveryLifecycleStatus.arrivedAtPickup:
        return CanonicalOrderStatus.arrivedPickup;
      case DeliveryLifecycleStatus.packagePickedUp:
        return CanonicalOrderStatus.pickedUp;
      case DeliveryLifecycleStatus.goingToDrop:
        return CanonicalOrderStatus.inTransit;
      case DeliveryLifecycleStatus.delivered:
        return CanonicalOrderStatus.delivered;
      case DeliveryLifecycleStatus.receiverUnavailable:
        return CanonicalOrderStatus.receiverUnavailable;
      case DeliveryLifecycleStatus.parcelAtCompanyOffice:
        return CanonicalOrderStatus.parcelAtCompanyOffice;
    }
  }

  Widget _moneyRow(String label, double amount, NumberFormat currency) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: RiderTextStyles.caption)),
          Text(currency.format(amount), style: RiderTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
