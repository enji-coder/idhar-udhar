import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/dummy/rider_finance.dart';
import '../../features/wallet/wallet_topup_checkout.dart';
import '../../state/rider_session.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_secondary_button.dart';
import '../../widgets/rider_text_field.dart';

class RiderWalletScreen extends ConsumerStatefulWidget {
  const RiderWalletScreen({super.key});

  @override
  ConsumerState<RiderWalletScreen> createState() => _RiderWalletScreenState();
}

class _RiderWalletScreenState extends ConsumerState<RiderWalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(riderSessionProvider.notifier).refreshWallet());
    });
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(riderWalletBalanceProvider);
    final codDue = ref.watch(riderCodDueProvider);
    final last = ref.watch(riderLastSettlementProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RiderGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current balance', style: RiderTextStyles.caption),
                const SizedBox(height: RiderSpacing.sm),
                Text(
                  currency.format(balance),
                  style: RiderTextStyles.display,
                ),
                const SizedBox(height: RiderSpacing.sm),
                Text(
                  'COD Due ${currency.format(codDue)}',
                  style: RiderTextStyles.bodyMedium,
                ),
                const SizedBox(height: RiderSpacing.sm),
                Text(
                  'Recharge first clears COD Due. Wallet never goes below ₹0.',
                  style: RiderTextStyles.caption,
                ),
                if (last != null && last.settledAgainstCod > 0) ...[
                  const SizedBox(height: RiderSpacing.sm),
                  Text(
                    'Gross ${currency.format(last.grossEarning)} · COD settlement ${currency.format(last.settledAgainstCod)} · Available ${currency.format(last.availableCredit)}',
                    style: RiderTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: RiderSpacing.xl),
          RiderPrimaryButton(
            label: 'Add Money',
            onPressed: () => _amountSheet(
              context: context,
              ref: ref,
              title: 'Add Money',
              confirmLabel: 'Add',
              onConfirm: (amount) async {
                try {
                  final session =
                      await ref.read(walletApiProvider).beginTopUp(amount);
                  await openRiderWalletTopUpCheckout(session);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Payment submitted. Balance updates after confirmation.',
                        ),
                      ),
                    );
                  }
                  // Poll briefly; credit only arrives after webhook verification.
                  for (var i = 0; i < 5; i++) {
                    await Future<void>.delayed(const Duration(seconds: 2));
                    await ref
                        .read(riderSessionProvider.notifier)
                        .refreshWallet();
                  }
                } on ApiException catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.message)),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: RiderSpacing.md),
          RiderSecondaryButton(
            label: 'Withdraw Money',
            onPressed: () => _amountSheet(
              context: context,
              ref: ref,
              title: 'Withdraw Money',
              confirmLabel: 'Withdraw',
              maxAmount: balance,
              onConfirm: (amount) async {
                try {
                  final bank = ref.read(riderBankProvider);
                  final String method =
                      bank.upiId.trim().isNotEmpty ? 'UPI' : 'BANK';
                  await ref.read(walletApiProvider).withdraw(
                        amount: amount,
                        payoutMethod: method,
                      );
                  await ref.read(riderSessionProvider.notifier).refreshWallet();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Withdrawal requested. Funds are held until processed.',
                        ),
                      ),
                    );
                  }
                } on ApiException catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.message)),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showRiderWalletAmountSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String confirmLabel,
  required FutureOr<void> Function(double amount) onConfirm,
  double? maxAmount,
}) {
  return _amountSheet(
    context: context,
    ref: ref,
    title: title,
    confirmLabel: confirmLabel,
    onConfirm: onConfirm,
    maxAmount: maxAmount,
  );
}

Future<void> _amountSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String confirmLabel,
  required FutureOr<void> Function(double amount) onConfirm,
  double? maxAmount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RiderColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(RiderRadius.xl)),
    ),
    builder: (context) {
      return _WalletAmountSheet(
        title: title,
        confirmLabel: confirmLabel,
        onConfirm: onConfirm,
        maxAmount: maxAmount,
      );
    },
  );
}

class _WalletAmountSheet extends StatefulWidget {
  const _WalletAmountSheet({
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    this.maxAmount,
  });

  final String title;
  final String confirmLabel;
  final FutureOr<void> Function(double amount) onConfirm;
  final double? maxAmount;

  @override
  State<_WalletAmountSheet> createState() => _WalletAmountSheetState();
}

class _WalletAmountSheetState extends State<_WalletAmountSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amountFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final double? amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    final double? maxAmount = widget.maxAmount;
    if (maxAmount != null && amount > maxAmount) {
      setState(() => _error = 'Amount exceeds available balance');
      return;
    }
    setState(() => _submitting = true);
    var closeSheet = false;
    try {
      await widget.onConfirm(amount);
      closeSheet = true;
    } finally {
      if (!closeSheet && mounted) {
        setState(() => _submitting = false);
      }
    }
    if (!closeSheet || !mounted) {
      return;
    }
    _amountFocus.unfocus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        RiderSpacing.xl,
        RiderSpacing.xl,
        RiderSpacing.xl,
        RiderSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: RiderTextStyles.title),
          const SizedBox(height: RiderSpacing.sm),
          Text(
            'Payments are confirmed by the server. COD Due is settled first on credit.',
            style: RiderTextStyles.caption,
          ),
          const SizedBox(height: RiderSpacing.lg),
          RiderTextField(
            controller: _controller,
            focusNode: _amountFocus,
            label: 'Amount (₹)',
            hint: '500',
            prefixIcon: Icons.currency_rupee_rounded,
            keyboardType: TextInputType.number,
            errorText: _error,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
          const SizedBox(height: RiderSpacing.lg),
          RiderPrimaryButton(
            label: _submitting ? 'Please wait…' : widget.confirmLabel,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
