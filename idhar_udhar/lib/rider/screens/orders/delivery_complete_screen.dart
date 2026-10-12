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
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';

/// Shown only after the server has confirmed `DELIVERED`.
class DeliveryCompleteScreen extends ConsumerWidget {
  const DeliveryCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RiderOrder? order = ref.watch(activeOrderProvider);
    final String? crn = _present(order?.crn);
    final double? earning = _earning(order?.riderAmount);
    final NumberFormat currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: earning != null && earning == earning.roundToDouble()
          ? 0
          : 2,
    );

    return RiderScaffold(
      bottom: RiderPrimaryButton(
        label: 'Back to Dashboard',
        onPressed: () {
          ref.read(activeOrderProvider.notifier).state = null;
          ref.read(deliveryStatusProvider.notifier).state =
              DeliveryLifecycleStatus.accepted;
          context.go(RiderRoutes.dashboard);
        },
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
            Text('Delivery complete', style: RiderTextStyles.heading),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'Congratulations. This order has been delivered.',
              style: RiderTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivered', style: RiderTextStyles.title),
                  if (crn != null) ...<Widget>[
                    const SizedBox(height: RiderSpacing.md),
                    Text('CRN', style: RiderTextStyles.caption),
                    Text(crn, style: RiderTextStyles.bodyMedium),
                  ],
                  if (earning != null) ...<Widget>[
                    const SizedBox(height: RiderSpacing.md),
                    Text('Earning', style: RiderTextStyles.caption),
                    Text(
                      currency.format(earning),
                      style: RiderTextStyles.bodyMedium.copyWith(
                        color: RiderColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _present(String? value) {
  final String text = (value ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  return text;
}

double? _earning(double? amount) {
  if (amount == null || !amount.isFinite || amount <= 0) {
    return null;
  }
  return amount;
}
