import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/customer/core/state/booking_api.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/waiting_charge_checkout.dart';
import 'package:idhar_udhar/customer/shared/widgets/custom_dialog.dart';
import 'package:idhar_udhar/customer/shared/widgets/custom_snack_bar.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';

/// Shows the waiting-charge choice once the server outstanding amount is known.
/// Pay now opens Cashfree. Pay later leaves the receivable outstanding.
class WaitingChargePrompt extends ConsumerStatefulWidget {
  const WaitingChargePrompt({
    required this.orderId,
    required this.outstanding,
    super.key,
  });

  final String orderId;
  final double outstanding;

  @override
  ConsumerState<WaitingChargePrompt> createState() => _WaitingChargePromptState();
}

class _WaitingChargePromptState extends ConsumerState<WaitingChargePrompt> {
  bool _shown = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_show());
    });
  }

  Future<void> _show() async {
    if (!mounted || _shown || widget.outstanding <= 0) {
      return;
    }
    _shown = true;
    final String amount = widget.outstanding.toStringAsFixed(
      widget.outstanding == widget.outstanding.roundToDouble() ? 0 : 2,
    );
    final bool? payNow = await CustomDialog.show(
      context: context,
      title: 'Additional Waiting Charge: ₹$amount',
      message:
          'Your trip fare is already paid. This waiting charge is separate. Pay it now, or clear it before your next booking.',
      confirmLabel: 'Pay now',
      cancelLabel: 'Pay later',
    );
    if (payNow == true) {
      await _pay();
    }
  }

  Future<void> _pay() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ReceivableClearance session = await ref
          .read(ordersApiProvider)
          .startReceivableClearance(widget.orderId);
      await openReceivableCheckout(session);
      ref.invalidate(orderServerViewProvider(widget.orderId));
      final ApiOrder latest =
          await ref.read(ordersApiProvider).getById(widget.orderId);
      if (!mounted) {
        return;
      }
      final double due = latest.receivableOutstanding ?? widget.outstanding;
      CustomSnackBar.success(
        context,
        due <= 0
            ? 'Waiting charge paid.'
            : 'Payment submitted. It is confirmed when the outstanding amount is cleared.',
      );
    } on ApiException catch (error) {
      if (mounted) {
        CustomSnackBar.error(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.error(
          context,
          'Waiting payment could not be started. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox.shrink();
  }
}
