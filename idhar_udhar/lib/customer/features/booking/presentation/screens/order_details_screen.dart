import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
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
import '../../../../shared/widgets/customer_order_ui.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';
import '../widgets/waiting_charge_prompt.dart';

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({required this.orderId, super.key});

  final String orderId;

  Future<void> _bookAgain(
    BuildContext context,
    WidgetRef ref,
    MockOrder order,
  ) async {
    final String id = order.apiId;
    try {
      final ApiOrder source = await ref.read(ordersApiProvider).getById(id);
      final notifier = ref.read(bookingDraftProvider.notifier);
      notifier.beginNewBooking();
      ref.read(backendQuoteHoldProvider.notifier).state = null;
      final List<ApiStop> pickups = source.stops
          .where((ApiStop stop) => stop.stopType == 'PICKUP')
          .toList(growable: false);
      final List<ApiStop> drops = source.stops
          .where((ApiStop stop) => stop.stopType == 'DROP')
          .toList(growable: false);
      if (pickups.isNotEmpty) {
        final ApiStop stop = pickups.first;
        notifier.setPickup(
          MockLocation(
            id: 'again_pickup',
            label: 'Pickup',
            address: stop.addressText,
            latitude: stop.latitude,
            longitude: stop.longitude,
          ),
        );
      }
      if (drops.isNotEmpty) {
        final ApiStop stop = drops.first;
        notifier.setDrop(
          MockLocation(
            id: 'again_drop',
            label: 'Drop',
            address: stop.addressText,
            latitude: stop.latitude,
            longitude: stop.longitude,
          ),
        );
        if ((stop.contactName ?? '').trim().isNotEmpty &&
            (stop.contactPhone ?? '').trim().isNotEmpty) {
          notifier.setReceiver(
            name: stop.contactName!.trim(),
            mobile: stop.contactPhone!.trim(),
          );
        }
      }
      if (source.vehicleCategoryId != null &&
          source.vehicleCategoryId!.isNotEmpty) {
        notifier.setCategory(source.vehicleCategoryId!);
      }
      if (source.packageWeightKg != null && source.packageWeightKg! > 0) {
        notifier.setWeight(source.packageWeightKg!);
      }
      if (!context.mounted) {
        return;
      }
      unawaited(context.push(AppRoutes.bookVehicle));
    } on ApiException catch (error) {
      if (context.mounted) {
        CustomSnackBar.error(context, error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    MockOrder? order = ref.read(sessionProvider.notifier).orderById(orderId);
    for (final o in ref.watch(sessionProvider).orders) {
      if (o.id == orderId ||
          o.backendOrderId == orderId ||
          o.displayId == orderId) {
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

    final ApiStop? pickupStop =
        CustomerOrderFormat.firstStop(serverOrder, 'PICKUP');
    final ApiStop? dropStop =
        CustomerOrderFormat.firstStop(serverOrder, 'DROP');
    final String? pickupContact = CustomerOrderFormat.contactLine(
      pickupStop?.contactName,
      pickupStop?.contactPhone,
    );
    final String? dropContact = CustomerOrderFormat.contactLine(
      dropStop?.contactName,
      dropStop?.contactPhone,
    );
    final String? vehicleReg =
        CustomerOrderFormat.vehicleRegistration(serverOrder, current);
    final String riderName =
        CustomerOrderFormat.riderDisplayName(current, serverOrder);
    final String? riderPhone =
        CustomerOrderFormat.riderPhone(current, serverOrder);
    final String pickupAddress = CustomerOrderFormat.displayLocation(
      stopAddress: pickupStop?.addressText,
      mappedAddress: current.pickup.address,
    );
    final String dropAddress = CustomerOrderFormat.displayLocation(
      stopAddress: dropStop?.addressText,
      mappedAddress: current.drop.address,
    );
    final String receiverName = (dropStop?.contactName ?? '').trim();
    final String receiverPhone = (dropStop?.contactPhone ?? '').trim();
    final String crn = (serverOrder?.crn?.trim().isNotEmpty == true)
        ? serverOrder!.crn!.trim()
        : (current.crn?.trim().isNotEmpty == true ? current.crn!.trim() : '—');

    final ApiFareSnapshot? snapshot = serverOrder?.fareSnapshot;
    final double baseFare = snapshot?.baseFare ?? current.fareBase;
    final double distanceCharge =
        snapshot?.distanceCharge ?? current.fareDistance;
    final double waiting = snapshot?.waiting ?? current.fareWaiting;
    final double surge = snapshot?.surge ?? current.fareSurge;
    final double toll = snapshot?.toll ?? current.fareToll;
    final double parking = snapshot?.parking ?? current.fareParking;
    final double discount = snapshot?.discount ?? current.discount;

    return GlassPageScaffold(
      bottom: Row(
        children: [
          if (current.canRequestResend) ...[
            Expanded(
              child: SecondaryButton(
                label: 'Resend Parcel',
                onPressed: () => _confirmResend(context, ref, current),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: AnimatedPrimaryButton(
              label: 'Book Again',
              showArrow: false,
              onPressed: () => unawaited(_bookAgain(context, ref, current)),
            ),
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
                  'Trip details',
                  style: AppTextStyles.headingS.copyWith(
                    color: AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CustomerOrderFormat.dateTime(current.createdAt),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            crn,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CustomerOrderFormat.currency(current.fare),
                          style: AppTextStyles.headingM.copyWith(
                            color: AppColors.navyDeep,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        OrderStatusPill(
                          label: current.statusLabel,
                          status: current.status,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (current.customerNotice != null) ...[
            GlassContainer(
              child: Text(current.customerNotice!, style: AppTextStyles.body),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeAssetImage(
                      path: current.vehicle.imagePath,
                      height: 64,
                      width: 64,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicleReg != null
                                ? '${current.vehicle.name} · $vehicleReg'
                                : current.vehicle.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            riderName,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (riderPhone != null) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Row(
                              children: [
                                Text(
                                  riderPhone,
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Icon(
                                  Icons.phone_in_talk_outlined,
                                  size: 16,
                                  color: AppColors.orange,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (current.status == OrderStatus.delivered &&
                    serverId != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Divider(color: AppColors.borderSubtle.withValues(alpha: 0.8)),
                  const SizedBox(height: AppSpacing.sm),
                  _RateDriver(
                    orderId: serverId,
                    existing: serverOrder?.customerRating,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OrderSectionTitle('Trip route'),
                OrderRouteTimeline(
                  pickupContact: pickupContact,
                  pickupAddress: pickupAddress,
                  dropContact: dropContact,
                  dropAddress: dropAddress,
                ),
                for (int i = 0; i < current.extraDrops.length; i++) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Drop ${i + 2}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    current.extraDrops[i].address,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (receiverName.isNotEmpty || receiverPhone.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OrderSectionTitle('Receiver'),
                  if (receiverName.isNotEmpty)
                    _DetailRow('Name', receiverName),
                  if (receiverPhone.isNotEmpty)
                    _DetailRow('Phone', receiverPhone),
                  _DetailRow('Address', dropAddress),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OrderSectionTitle('Fare details'),
                OrderFareRow(
                  label: 'Trip fare',
                  value: CustomerOrderFormat.currency(current.confirmedTripFare),
                ),
                OrderFareRow(
                  label: 'Base fare',
                  value: CustomerOrderFormat.currency(baseFare),
                ),
                OrderFareRow(
                  label: 'Distance charge',
                  value: CustomerOrderFormat.currency(distanceCharge),
                ),
                OrderFareRow(
                  label: 'Waiting',
                  value: CustomerOrderFormat.currency(waiting),
                ),
                OrderFareRow(
                  label: 'Surge',
                  value: CustomerOrderFormat.currency(surge),
                ),
                OrderFareRow(
                  label: 'Toll',
                  value: CustomerOrderFormat.currency(toll),
                ),
                OrderFareRow(
                  label: 'Parking',
                  value: CustomerOrderFormat.currency(parking),
                ),
                OrderFareRow(
                  label: 'Discount',
                  value: CustomerOrderFormat.currency(discount),
                ),
                if (serverOrder?.waitingAmount != null)
                  OrderFareRow(
                    label: 'Waiting charges',
                    value: CustomerOrderFormat.currency(
                      serverOrder!.waitingAmount!,
                    ),
                  ),
                if (serverOrder?.receivableOutstanding != null)
                  OrderFareRow(
                    label: 'Previous payment due',
                    value: CustomerOrderFormat.currency(
                      serverOrder!.receivableOutstanding!,
                    ),
                  ),
                if (current.additionalCharge > 0)
                  OrderFareRow(
                    label: 'Additional charge',
                    value: CustomerOrderFormat.currency(current.additionalCharge),
                  ),
                if (current.resendCharge > 0)
                  OrderFareRow(
                    label: 'Resend charge',
                    value: CustomerOrderFormat.currency(current.resendCharge),
                  ),
                if (current.cancellationFee > 0)
                  OrderFareRow(
                    label: 'Cancellation fee',
                    value:
                        CustomerOrderFormat.currency(current.cancellationFee),
                  ),
                const Divider(height: AppSpacing.lg),
                OrderFareRow(
                  label: 'Amount payable',
                  value: CustomerOrderFormat.currency(current.fare),
                  emphasize: true,
                ),
                if (serverId != null &&
                    (serverOrder?.receivableOutstanding ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: WaitingChargePrompt(
                      orderId: serverId,
                      outstanding: serverOrder!.receivableOutstanding!,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OrderSectionTitle('Order information'),
                _DetailRow(
                  'Order ID',
                  (current.displayId != null && current.displayId!.isNotEmpty)
                      ? current.displayId!
                      : current.id,
                ),
                _DetailRow('Package', current.packageLabel),
                _DetailRow(
                  'Weight',
                  '${current.weightKg.toStringAsFixed(0)} kg',
                ),
                _DetailRow('Payment', current.paymentSummaryLabel),
                _DetailRow(
                  'Payment status',
                  current.paymentPlan.overallStatus.label,
                ),
                _DetailRow(
                  'Customer due',
                  CustomerOrderFormat.currency(
                    current.paymentPlan.responsibility.customerAmount,
                  ),
                ),
                _DetailRow(
                  'Receiver due',
                  CustomerOrderFormat.currency(
                    current.paymentPlan.responsibility.receiverAmount,
                  ),
                ),
                if (current.parentOrderId != null)
                  _DetailRow('Original order', current.parentOrderId!),
                if (current.resendCaseLabel != null)
                  _DetailRow('Resend', current.resendCaseLabel!),
                if (current.failedReason != null)
                  _DetailRow('Failure', current.failedReason!),
                if (current.invoiceSent)
                  _DetailRow(
                    'Invoice',
                    current.invoiceEmail.isEmpty
                        ? 'Generated & sent'
                        : 'Sent to ${current.invoiceEmail}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _confirmResend(
    BuildContext context,
    WidgetRef ref,
    MockOrder current,
  ) async {
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
    if (ok != true) {
      return;
    }
    ref.read(bookingDraftProvider.notifier).attachActive(current);
    final MockOrder? resend = ref
        .read(bookingDraftProvider.notifier)
        .requestResend(resendDistanceKm: km);
    final MockOrder? original =
        ref.read(bookingDraftProvider.notifier).takePendingOriginalAfterResend();
    if (original != null) {
      ref.read(sessionProvider.notifier).updateOrder(original);
    }
    if (resend != null) {
      ref.read(sessionProvider.notifier).upsertOrder(resend);
      if (context.mounted) {
        context.go(AppRoutes.bookSearching);
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMedium),
          ),
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
      final ApiCustomerRating saved =
          await ref.read(ordersApiProvider).rateOrder(
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
      return Text(
        saved.comment == null || saved.comment!.isEmpty
            ? 'Your rating: ${saved.stars} ★'
            : 'Your rating: ${saved.stars} ★  ${saved.comment}',
        style: AppTextStyles.bodyMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate your driver',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List<Widget>.generate(5, (int index) {
            final int value = index + 1;
            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: _busy ? null : () => setState(() => _stars = value),
              icon: Icon(
                value <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                color: AppColors.orange,
                size: 32,
              ),
            );
          }),
        ),
        TextField(
          controller: _comment,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Optional comment',
            filled: true,
            fillColor: AppColors.greyLight.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(AppSpacing.sm),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _stars < 1 || _busy ? null : _submit,
            child: Text(_busy ? 'Submitting…' : 'Submit rating'),
          ),
        ),
      ],
    );
  }
}
