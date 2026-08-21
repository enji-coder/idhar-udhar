import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_section_header.dart';

class AcceptConfirmationScreen extends ConsumerWidget {
  const AcceptConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order =
        ref.watch(activeOrderProvider) ??
        ref.watch(dummyRiderRepositoryProvider).getIncomingOrder();
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return RiderScaffold(
      bottom: RiderPrimaryButton(
        label: 'View Order Details',
        onPressed: () => context.push(RiderRoutes.orderDetails),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: RiderSpacing.xxl),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: RiderColors.success.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 48,
                color: RiderColors.success,
              ),
            ),
            const SizedBox(height: RiderSpacing.lg),
            Text('Order Accepted!', style: RiderTextStyles.heading),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'Head to pickup to start this delivery.',
              style: RiderTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order.id}', style: RiderTextStyles.title),
                  const SizedBox(height: RiderSpacing.md),
                  Text('Pickup', style: RiderTextStyles.caption),
                  Text(order.pickup, style: RiderTextStyles.bodyMedium),
                  const SizedBox(height: RiderSpacing.md),
                  Text('Drop', style: RiderTextStyles.caption),
                  Text(order.drop, style: RiderTextStyles.bodyMedium),
                  const SizedBox(height: RiderSpacing.md),
                  Text(
                    'Earnings ${currency.format(order.estimatedEarnings)}',
                    style: RiderTextStyles.bodyMedium.copyWith(
                      color: RiderColors.primary,
                      fontWeight: FontWeight.w700,
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
}

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order =
        ref.watch(activeOrderProvider) ??
        ref.watch(dummyRiderRepositoryProvider).getIncomingOrder();
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return RiderScaffold(
      appBar: AppBar(
        title: Text('Order #${order.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: RiderPrimaryButton(
        label: 'Start Delivery',
        onPressed: () => context.push(RiderRoutes.activeDelivery),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RiderStatusChip(
                    label: 'Pickup pending',
                    tone: RiderChipTone.warning,
                    icon: Icons.flag_rounded,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  _Detail(
                    label: 'Pickup',
                    value: order.pickup,
                    icon: Icons.store_mall_directory_rounded,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _Detail(
                    label: 'Drop',
                    value: order.drop,
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _Detail(
                    label: 'Distance',
                    value: '${order.distanceKm} km',
                    icon: Icons.route_rounded,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _Detail(
                    label: 'Estimated Earnings',
                    value: currency.format(order.estimatedEarnings),
                    icon: Icons.payments_rounded,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _Detail(
                    label: 'Trip Amount',
                    value: currency.format(order.tripAmount),
                    icon: Icons.receipt_long_rounded,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _Detail(
                    label: 'Customer Payment',
                    value: currency.format(order.customerResponsibility),
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _Detail(
                    label: 'Receiver Payment',
                    value: currency.format(order.receiverResponsibility),
                    icon: Icons.person_pin_circle_outlined,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _Detail(
                    label: 'Payment Status',
                    value: order.paymentStatusLabel,
                    icon: Icons.credit_score_rounded,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _Detail(
                    label: 'Payment',
                    value: order.paymentLabel,
                    icon: Icons.credit_card_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: RiderSpacing.md),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RiderSectionHeader(title: 'Customer'),
                  const SizedBox(height: RiderSpacing.md),
                  Text(order.customerMaskedName, style: RiderTextStyles.title),
                  const SizedBox(height: RiderSpacing.xs),
                  Text(
                    order.customerMaskedPhone,
                    style: RiderTextStyles.caption,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: RiderColors.secondary,
                                content: Text(
                                  'Masked calling (demo)',
                                  style: RiderTextStyles.bodyMedium.copyWith(
                                    color: RiderColors.textOnPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.call_rounded),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RiderColors.primary,
                            side: const BorderSide(color: RiderColors.primary),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: RiderSpacing.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: RiderColors.secondary,
                                content: Text(
                                  'Navigation (demo)',
                                  style: RiderTextStyles.bodyMedium.copyWith(
                                    color: RiderColors.textOnPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.navigation_rounded),
                          label: const Text('Navigate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RiderColors.primary,
                            side: const BorderSide(color: RiderColors.primary),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: RiderColors.primary, size: 20),
        const SizedBox(width: RiderSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: RiderTextStyles.caption),
              Text(value, style: RiderTextStyles.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
