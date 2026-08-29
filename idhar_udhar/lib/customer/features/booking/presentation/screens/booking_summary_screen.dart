import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/business/business.dart';

import '../../../../core/constants/app_copy.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_api.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/custom_snack_bar.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class BookingSummaryScreen extends ConsumerStatefulWidget {
  const BookingSummaryScreen({super.key});

  @override
  ConsumerState<BookingSummaryScreen> createState() =>
      _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends ConsumerState<BookingSummaryScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prefetchQuote());
    });
  }

  Future<void> _prefetchQuote() async {
    try {
      await ensureCustomerQuote(ref);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Confirm path shows the mapped error; keep the existing layout.
    }
  }

  Future<void> _confirm() async {
    if (_busy) {
      return;
    }
    final BookingDraft draft = ref.read(bookingDraftProvider);
    final String? blocked =
        draft.incompleteStopMessage ?? draft.paymentValidationError;
    if (blocked != null) {
      CustomSnackBar.error(context, blocked);
      return;
    }
    setState(() => _busy = true);
    try {
      final order = await confirmCustomerBooking(ref);
      if (!mounted) {
        return;
      }
      ref.read(sessionProvider.notifier).upsertOrder(order);
      ref.read(backendQuoteHoldProvider.notifier).state = null;
      context.go(AppRoutes.bookSearching);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      CustomSnackBar.error(context, error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      CustomSnackBar.error(context, 'Could not confirm this booking.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final BackendQuoteHold? hold = ref.watch(backendQuoteHoldProvider);
    final ApiQuote? quote = hold?.quote;
    final double displayedFare = quote?.tripFare ?? draft.estimatedFare;

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Confirm Booking',
        isLoading: _busy,
        onPressed: _busy ? null : _confirm,
      ),
      child: ListView(
        children: [
          Row(
            children: [
              const IuBackButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Booking Summary',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassContainer(
            hero: true,
            showAmbientGlow: true,
            ambientColor: AppColors.orange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('Pickup', draft.pickup?.address ?? '—'),
                const Divider(height: 24),
                _row('Drop', draft.drop?.address ?? '—'),
                for (int i = 0; i < draft.extraDrops.length; i++) ...[
                  const Divider(height: 24),
                  _row('Drop ${i + 2}', draft.extraDrops[i].address),
                ],
                const Divider(height: 24),
                _row('Vehicle', draft.vehicle?.name ?? '—'),
                const Divider(height: 24),
                _row('Package', '${draft.categoryLabel} · ${draft.sizeLabel}'),
                const Divider(height: 24),
                _row('Weight', '${draft.weightKg.toStringAsFixed(0)} kg'),
                if (draft.instructions.trim().isNotEmpty) ...[
                  const Divider(height: 24),
                  _row('Notes', draft.instructions),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (draft.vehicle != null)
            GlassContainer(
              child: Row(
                children: [
                  SafeAssetImage(
                    path: draft.vehicle!.imagePath,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(draft.vehicle!.name,
                            style: AppTextStyles.headingS),
                        Text(
                          'ETA ~ ${draft.vehicle!.etaMinutes} min',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${displayedFare.toStringAsFixed(0)}',
                    style: AppTextStyles.headingM.copyWith(
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Fare breakdown', style: AppTextStyles.headingS),
                const SizedBox(height: AppSpacing.md),
                _fareLine('Trip Fare', quote?.tripFare ?? draft.fareQuote.tripFare),
                if ((quote?.distanceCharge ?? draft.fareBreakdown.distanceCharge) > 0)
                  _fareLine(
                    'Distance',
                    quote?.distanceCharge ?? draft.fareBreakdown.distanceCharge,
                  ),
                if ((quote?.waiting ?? draft.fareBreakdown.waitingCharge) > 0)
                  _fareLine(
                    'Waiting',
                    quote?.waiting ?? draft.fareBreakdown.waitingCharge,
                  ),
                if ((quote?.discount ?? draft.fareBreakdown.discount) > 0)
                  _fareLine(
                    'Discount',
                    quote?.discount ?? draft.fareBreakdown.discount,
                  ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Amount payable',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    Text(
                      '₹${draft.fareBreakdown.total.toStringAsFixed(0)}',
                      style: AppTextStyles.headingS.copyWith(
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Payment', style: AppTextStyles.headingS),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Who pays is separate from how they pay.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Who pays', style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                _choice(
                  selected: draft.whoPays == PaymentWhoPays.customer,
                  label: 'Customer',
                  onTap: () => ref
                      .read(bookingDraftProvider.notifier)
                      .setWhoPays(PaymentWhoPays.customer),
                ),
                const SizedBox(height: AppSpacing.sm),
                _choice(
                  selected: draft.whoPays == PaymentWhoPays.receiver,
                  label: 'Receiver',
                  onTap: () => ref
                      .read(bookingDraftProvider.notifier)
                      .setWhoPays(PaymentWhoPays.receiver),
                ),
                const SizedBox(height: AppSpacing.sm),
                _choice(
                  selected: draft.whoPays == PaymentWhoPays.split,
                  label: 'Customer + Receiver',
                  onTap: () => ref
                      .read(bookingDraftProvider.notifier)
                      .setWhoPays(PaymentWhoPays.split),
                ),
                if (draft.whoPays == PaymentWhoPays.split) ...[
                  const SizedBox(height: AppSpacing.md),
                  _amountField(
                    label: 'Customer amount',
                    value: draft.customerResponsibility,
                    onChanged: (v) => ref
                        .read(bookingDraftProvider.notifier)
                        .setCustomerAmount(v),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Receiver amount ₹${draft.receiverResponsibility.toStringAsFixed(0)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (draft.customerResponsibility > 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Customer pays how',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _methodModes(
                    current: draft.customerMethodMode,
                    onChanged: (mode) => ref
                        .read(bookingDraftProvider.notifier)
                        .setCustomerMethodMode(mode),
                  ),
                  if (draft.customerMethodMode == PayerMethodMode.split) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _amountField(
                      label: 'Customer online',
                      value: draft.paymentAllocation.customerOnline,
                      onChanged: (v) => ref
                          .read(bookingDraftProvider.notifier)
                          .setCustomerOnlineAmount(v),
                    ),
                    Text(
                      'Customer cash ₹${draft.paymentAllocation.customerCash.toStringAsFixed(0)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
                if (draft.receiverResponsibility > 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Receiver pays how',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _methodModes(
                    current: draft.receiverMethodMode,
                    onChanged: (mode) => ref
                        .read(bookingDraftProvider.notifier)
                        .setReceiverMethodMode(mode),
                  ),
                  if (draft.receiverMethodMode == PayerMethodMode.split) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _amountField(
                      label: 'Receiver online',
                      value: draft.paymentAllocation.receiverOnline,
                      onChanged: (v) => ref
                          .read(bookingDraftProvider.notifier)
                          .setReceiverOnlineAmount(v),
                    ),
                    Text(
                      'Receiver cash ₹${draft.paymentAllocation.receiverCash.toStringAsFixed(0)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (draft.paymentAllocation.receiverOnline > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        'Receiver online is architecture ready. Payment provider integration is pending. It stays UNPAID until a real payment confirms.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
                const Divider(height: 28),
                _row(
                  'Trip / Fare',
                  '₹${displayedFare.toStringAsFixed(0)}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _row(
                  'Customer',
                  '₹${draft.customerResponsibility.toStringAsFixed(0)}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _row(
                  'Receiver',
                  '₹${draft.receiverResponsibility.toStringAsFixed(0)}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _row(
                  'Methods',
                  _methodsLabel(draft.paymentAllocation),
                ),
                const SizedBox(height: AppSpacing.sm),
                _row(
                  'Total',
                  '₹${draft.payableTotal.toStringAsFixed(0)}',
                ),
                if (draft.paymentAllocation.onlineTotal > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'Online amounts stay UNPAID until a payment provider confirms. This demo does not fake a successful charge.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            backgroundColor: AppColors.softPeach.withValues(alpha: 0.45),
            child: Text(
              AppCopy.estimatedFare,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.orange : AppColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }

  Widget _methodModes({
    required PayerMethodMode current,
    required ValueChanged<PayerMethodMode> onChanged,
  }) {
    return Column(
      children: [
        _choice(
          selected: current == PayerMethodMode.online,
          label: 'Online',
          onTap: () => onChanged(PayerMethodMode.online),
        ),
        const SizedBox(height: AppSpacing.sm),
        _choice(
          selected: current == PayerMethodMode.cash,
          label: 'Cash',
          onTap: () => onChanged(PayerMethodMode.cash),
        ),
        const SizedBox(height: AppSpacing.sm),
        _choice(
          selected: current == PayerMethodMode.split,
          label: 'Online + Cash',
          onTap: () => onChanged(PayerMethodMode.split),
        ),
      ],
    );
  }

  Widget _amountField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          key: ValueKey(label),
          initialValue: value.toStringAsFixed(0),
          keyboardType: TextInputType.number,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            prefixText: '₹ ',
            isDense: true,
            filled: true,
            fillColor: AppColors.softPeach.withValues(alpha: 0.45),
            border: OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (raw) => onChanged(double.tryParse(raw) ?? 0),
        ),
      ],
    );
  }

  String _methodsLabel(PaymentAllocation allocation) {
    final List<String> parts = <String>[];
    if (allocation.customerOnline > 0) {
      parts.add('Customer Online ₹${allocation.customerOnline.toStringAsFixed(0)}');
    }
    if (allocation.customerCash > 0) {
      parts.add('Customer Cash ₹${allocation.customerCash.toStringAsFixed(0)}');
    }
    if (allocation.receiverOnline > 0) {
      parts.add('Receiver Online ₹${allocation.receiverOnline.toStringAsFixed(0)}');
    }
    if (allocation.receiverCash > 0) {
      parts.add('Receiver Cash ₹${allocation.receiverCash.toStringAsFixed(0)}');
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
      ],
    );
  }

  Widget _fareLine(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
