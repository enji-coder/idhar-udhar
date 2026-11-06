import 'package:flutter/material.dart';
import 'package:idhar_udhar/shared/format/inr_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:idhar_udhar/shared/api/orders_api.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_api.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../widgets/waiting_charge_prompt.dart';

class DeliveryCompletedScreen extends ConsumerWidget {
  const DeliveryCompletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(bookingDraftProvider).activeOrder;
    final String? serverId = order?.backendOrderId;
    final ApiOrder? serverOrder = serverId == null
        ? null
        : ref.watch(orderServerViewProvider(serverId)).asData?.value;
    final bool serverDelivered = serverOrder?.canonicalStatus == 'DELIVERED';

    return GlassPageScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedPrimaryButton(
            label: 'View Order',
            onPressed: () {
              if (order != null) {
                context.push(AppRoutes.orderDetailsPath(order.id));
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Back to Home',
            onPressed: () {
              ref.read(bookingDraftProvider.notifier).reset();
              ref.read(backendQuoteHoldProvider.notifier).state = null;
              context.go(AppRoutes.home);
            },
          ),
        ],
      ),
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.xxl),
          const Center(
            child: SafeAssetImage(
              path: AssetPaths.parcel,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Delivery completed',
            style: AppTextStyles.headingM,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Thanks for choosing IDHAR UDHAR',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (serverId != null && (serverOrder?.receivableOutstanding ?? 0) > 0)
            WaitingChargePrompt(
              orderId: serverId,
              outstanding: serverOrder!.receivableOutstanding!,
            ),
          GlassContainer(
            hero: true,
            showAmbientGlow: true,
            ambientColor: AppColors.orange,
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.orange,
                  size: 36,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  serverId == null
                      ? 'Demo orders do not include an official invoice.'
                      : serverDelivered
                          ? 'The invoice can be downloaded from Order Details when the server has issued it.'
                          : 'An official invoice is available only after the server confirms delivery.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Column(
              children: [
                _line('Order', order?.id ?? '—'),
                _line('Fare', order?.fare == null ? '—' : formatInr(order!.fare)),
                _line('Vehicle', order?.vehicle.name ?? '—'),
                _line('Rider', order?.rider?.name ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Column(
              children: [
                Text('Rate your delivery', style: AppTextStyles.headingS),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.star_rounded,
                          color: AppColors.orange, size: 32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(v, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
