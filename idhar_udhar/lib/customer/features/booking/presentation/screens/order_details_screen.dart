import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:idhar_udhar/shared/business/business.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/custom_dialog.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    MockOrder? order = ref.read(sessionProvider.notifier).orderById(orderId);
    for (final o in ref.watch(sessionProvider).orders) {
      if (o.id == orderId || o.backendOrderId == orderId || o.displayId == orderId) {
        order = o;
        break;
      }
    }

    if (order == null) {
      return GlassPageScaffold(
        child: Column(
          children: [
            const Align(alignment: Alignment.centerLeft, child: IuBackButton()),
            const Spacer(),
            Text('Order not found', style: AppTextStyles.headingS),
            const Spacer(),
          ],
        ),
      );
    }

    final MockOrder current = order;

    return GlassPageScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current.canRequestResend)
            AnimatedPrimaryButton(
              label: 'Resend Parcel',
              onPressed: () async {
                const double km = 5;
                final bool ended =
                    OrderLifecycle.originalTripEnded(current.canonicalStatus);
                final ResendQuote quote = ResendEngine.quote(
                  originalTripEnded: ended,
                  distanceKm: km,
                  baseFare: ended ? current.confirmedTripFare : 0,
                );
                final String detail = ended
                    ? 'Ride ended.\nBase fare ₹${quote.baseFare.toStringAsFixed(0)} + ₹10/km resend ₹${quote.resendSurcharge.toStringAsFixed(0)}.\nYou pay ₹${quote.customerPays.toStringAsFixed(0)}.'
                    : 'Ride is still active.\n₹10/km = ₹${quote.customerPays.toStringAsFixed(0)} (₹8/km rider, ₹2/km company).';
                final bool? ok = await CustomDialog.show(
                  context: context,
                  title: 'Resend Parcel',
                  message: detail,
                  confirmLabel: 'Confirm resend',
                  cancelLabel: 'Not now',
                );
                if (ok != true) return;
                ref.read(bookingDraftProvider.notifier).attachActive(current);
                final MockOrder? resend = ref
                    .read(bookingDraftProvider.notifier)
                    .requestResend(resendDistanceKm: km);
                final MockOrder? original = ref
                    .read(bookingDraftProvider.notifier)
                    .takePendingOriginalAfterResend();
                if (original != null) {
                  ref.read(sessionProvider.notifier).updateOrder(original);
                }
                if (resend != null) {
                  ref.read(sessionProvider.notifier).upsertOrder(resend);
                  if (context.mounted) context.go(AppRoutes.bookSearching);
                }
              },
            ),
          if (current.canRequestResend) const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Close',
            onPressed: () => context.pop(),
          ),
        ],
      ),
      child: ListView(
        children: [
          Row(
            children: [
              const IuBackButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Order Details',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassContainer(
            child: Column(
              children: [
                SafeAssetImage(
                  path: order.vehicle.imagePath,
                  height: 96,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(order.id, style: AppTextStyles.headingM),
                Text(
                  order.statusLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (order.customerNotice != null) ...[
            GlassContainer(
              child: Text(order.customerNotice!, style: AppTextStyles.body),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          GlassContainer(
            child: Column(
              children: [
                _row('Date', _fmt(order.createdAt)),
                _row('Pickup', order.pickup.address),
                _row('Drop', order.drop.address),
                for (int i = 0; i < order.extraDrops.length; i++)
                  _row('Drop ${i + 2}', order.extraDrops[i].address),
                _row('Vehicle', order.vehicle.name),
                _row('Package', order.packageLabel),
                _row('Weight', '${order.weightKg.toStringAsFixed(0)} kg'),
                _row('Rider', order.rider?.name ?? '—'),
                _row('Trip Fare', '₹${order.confirmedTripFare.toStringAsFixed(0)}'),
                if (order.additionalCharge > 0)
                  _row(
                    'Additional charge',
                    '₹${order.additionalCharge.toStringAsFixed(0)}',
                  ),
                _row('Amount payable', '₹${order.fare.toStringAsFixed(0)}'),
                _row(
                  'Payment',
                  order.paymentSummaryLabel,
                ),
                _row(
                  'Payment status',
                  order.paymentPlan.overallStatus.label,
                ),
                _row(
                  'Customer due',
                  '₹${order.paymentPlan.responsibility.customerAmount.toStringAsFixed(0)}',
                ),
                _row(
                  'Receiver due',
                  '₹${order.paymentPlan.responsibility.receiverAmount.toStringAsFixed(0)}',
                ),
                if (order.parentOrderId != null)
                  _row('Original order', order.parentOrderId!),
                if (order.resendCaseLabel != null)
                  _row('Resend', order.resendCaseLabel!),
                if (order.failedReason != null)
                  _row('Failure', order.failedReason!),
                if (order.resendCharge > 0)
                  _row(
                    'Resend charge',
                    '₹${order.resendCharge.toStringAsFixed(0)}',
                  ),
                if (order.cancellationFee > 0)
                  _row(
                    'Cancellation fee',
                    '₹${order.cancellationFee.toStringAsFixed(0)}',
                  ),
                if (order.invoiceSent)
                  _row(
                    'Invoice',
                    order.invoiceEmail.isEmpty
                        ? 'Generated & sent'
                        : 'Sent to ${order.invoiceEmail}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(v, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}
