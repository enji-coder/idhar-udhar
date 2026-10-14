import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/models/rider_order.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_contact_call.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_section_header.dart';
import '../profile/rider_profile_screen.dart';

class AcceptConfirmationScreen extends ConsumerWidget {
  const AcceptConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RiderOrder? order = ref.watch(activeOrderProvider);
    if (order == null) return const _NoActiveOrder();
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
                  if (order.crn != null && order.crn!.isNotEmpty)
                    Text('CRN ${order.crn}', style: RiderTextStyles.caption),
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
    final RiderOrder? order = ref.watch(activeOrderProvider);
    if (order == null) return const _NoActiveOrder();
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final String? photoUrl = _httpPhotoUrl(
      ref.watch(riderProfileStateProvider).photoUrl,
    );

    return RiderScaffold(
      appBar: AppBar(
        title: Text('Order #${order.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RiderRoutes.dashboard),
        ),
        actions: [
          if (photoUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: RiderSpacing.lg),
              child: Center(
                child: RiderProfileAvatar(photoUrl: photoUrl, radius: 16),
              ),
            ),
        ],
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
                    value: order.distanceLabel,
                    icon: Icons.route_rounded,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _Detail(
                    label: 'Estimated time',
                    value: order.etaLabel,
                    icon: Icons.timer_outlined,
                  ),
                  // const SizedBox(height: RiderSpacing.md),
                  // _Detail(
                  //   label: 'Estimated Earnings',
                  //   value: currency.format(order.estimatedEarnings),
                  //   icon: Icons.payments_rounded,
                  // ),
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
                  const RiderSectionHeader(title: 'Contacts'),
                  const SizedBox(height: RiderSpacing.md),
                  RiderContactCall(
                    label: 'Sender',
                    name: order.senderName.trim().isEmpty
                        ? order.customerMaskedName
                        : order.senderName,
                    phone: order.senderPhone,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderContactCall(
                    label: 'Receiver',
                    name: order.receiverName,
                    phone: order.receiverPhone,
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

class _NoActiveOrder extends StatelessWidget {
  const _NoActiveOrder();

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RiderRoutes.dashboard),
        ),
      ),
      body: Center(
        child: Text(
          'No active order.',
          style: RiderTextStyles.caption,
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

String? _httpPhotoUrl(String? raw) {
  final String value = (raw ?? '').trim();
  final Uri? uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  if (uri.host.isEmpty) {
    return null;
  }
  return value;
}
