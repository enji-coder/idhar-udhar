import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/business/business.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_api.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/custom_dialog.dart';
import '../../../../shared/widgets/custom_snack_bar.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';
import '../widgets/waiting_charge_prompt.dart';

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
    final String? serverId = current.backendOrderId;
    final ApiOrder? serverOrder = serverId == null
        ? null
        : ref.watch(orderServerViewProvider(serverId)).asData?.value;

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
                _row('Date', '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}'),
                _row('Time', _time(order.createdAt)),
                _row(
                  'Order ID',
                  (order.displayId != null && order.displayId!.isNotEmpty)
                      ? order.displayId!
                      : order.id,
                ),
                _row('CRN', serverOrder?.crn ?? order.crn ?? '—'),
                _row('Status', order.statusLabel),
                _row('Pickup', order.pickup.address),
                _row('Drop', order.drop.address),
                for (int i = 0; i < order.extraDrops.length; i++)
                  _row('Drop ${i + 2}', order.extraDrops[i].address),
                _row('Vehicle', order.vehicle.name),
                _row('Package', order.packageLabel),
                _row('Weight', '${order.weightKg.toStringAsFixed(0)} kg'),
                _row('Rider', order.rider?.name ?? '—'),
                _row(
                  'Vehicle number',
                  order.rider?.vehicleLabel ?? '—',
                ),
                _row('Trip amount', '₹${order.fare.toStringAsFixed(0)}'),
                _row('Base fare', '₹${(serverOrder?.fareSnapshot?.baseFare ?? order.fareBase).toStringAsFixed(0)}'),
                _row('Distance charge', '₹${(serverOrder?.fareSnapshot?.distanceCharge ?? order.fareDistance).toStringAsFixed(0)}'),
                _row('Waiting', '₹${(serverOrder?.fareSnapshot?.waiting ?? order.fareWaiting).toStringAsFixed(0)}'),
                _row('Surge', '₹${(serverOrder?.fareSnapshot?.surge ?? order.fareSurge).toStringAsFixed(0)}'),
                _row('Toll', '₹${(serverOrder?.fareSnapshot?.toll ?? order.fareToll).toStringAsFixed(0)}'),
                _row('Parking', '₹${(serverOrder?.fareSnapshot?.parking ?? order.fareParking).toStringAsFixed(0)}'),
                _row('Discount', '₹${(serverOrder?.fareSnapshot?.discount ?? order.discount).toStringAsFixed(0)}'),
                _row('Trip Fare', '₹${order.confirmedTripFare.toStringAsFixed(0)}'),
                if (serverOrder?.waitingAmount != null)
                  _row(
                    'Waiting charges',
                    '₹${serverOrder!.waitingAmount!.toStringAsFixed(0)}',
                  ),
                if (serverOrder?.receivableOutstanding != null)
                  _row(
                    'Previous payment due',
                    '₹${serverOrder!.receivableOutstanding!.toStringAsFixed(0)}',
                  ),
                if (serverId != null &&
                    (serverOrder?.receivableOutstanding ?? 0) > 0)
                  WaitingChargePrompt(
                    orderId: serverId,
                    outstanding: serverOrder!.receivableOutstanding!,
                  ),
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
                if (current.status == OrderStatus.delivered && serverId != null)
                  _RateDriver(
                    orderId: serverId,
                    existing: serverOrder?.customerRating,
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

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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

class _RateDriver extends ConsumerStatefulWidget {
  const _RateDriver({required this.orderId, this.existing});

  final String orderId;
  final ApiCustomerRating? existing;

  @override
  ConsumerState<_RateDriver> createState() => _RateDriverState();
}

class _RateDriverState extends ConsumerState<_RateDriver> {
  int _stars = 0;
  bool _busy = false;
  ApiCustomerRating? _saved;
  final TextEditingController _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _saved = widget.existing;
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _stars < 1 || _saved != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ApiCustomerRating saved = await ref.read(ordersApiProvider).rateOrder(
            orderId: widget.orderId,
            stars: _stars,
            comment: _comment.text,
          );
      ref.invalidate(orderServerViewProvider(widget.orderId));
      if (!mounted) {
        return;
      }
      setState(() => _saved = saved);
      CustomSnackBar.success(context, 'Rating submitted.');
    } on ApiException catch (error) {
      if (mounted) {
        CustomSnackBar.error(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ApiCustomerRating? saved = _saved ?? widget.existing;
    if (saved != null && saved.stars > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          saved.comment == null || saved.comment!.isEmpty
              ? 'Your rating: ${saved.stars} ★'
              : 'Your rating: ${saved.stars} ★  ${saved.comment}',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate your driver', style: AppTextStyles.bodyMedium),
          TextField(
            controller: _comment,
            maxLength: 500,
            decoration: const InputDecoration(hintText: 'Optional comment'),
          ),
          Row(
            children: List<Widget>.generate(5, (int index) {
              final int value = index + 1;
              return IconButton(
                onPressed: _busy ? null : () => setState(() => _stars = value),
                icon: Icon(
                  value <= _stars ? Icons.star : Icons.star_border,
                  color: AppColors.orange,
                ),
              );
            }),
          ),
          TextButton(
            onPressed: _stars < 1 || _busy ? null : _submit,
            child: Text(_busy ? 'Submitting' : 'Submit rating'),
          ),
        ],
      ),
    );
  }
}
