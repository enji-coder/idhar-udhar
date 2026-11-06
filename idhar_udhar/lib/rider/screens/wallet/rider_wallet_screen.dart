import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/format/inr_format.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/dummy/rider_finance.dart';
import '../../features/orders/rider_order_board_providers.dart';
import '../../features/wallet/wallet_topup_checkout.dart';
import '../../routing/rider_routes.dart';
import '../../state/rider_payout_destination.dart';
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
    final String moneyStatus = ref.watch(riderOperationalStatusProvider);
    final double rechargeToResume = ref.watch(riderRechargeToResumeProvider);
    final double walletFloor = ref.watch(riderWalletSuspendFloorProvider);
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
                  moneyStatus == 'SUSPENDED_FOR_WALLET'
                      ? 'Service is paused. Balance ${currency.format(balance)}. Add at least ${currency.format(rechargeToResume)} to go above ${currency.format(walletFloor)}.'
                      : moneyStatus == 'CLEAR'
                          ? 'Service is active. A cash trip debits the company share here, so this balance can be negative.'
                          : 'Service is paused until COD Due is cleared. A recharge is applied to COD Due first.',
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
                  final walletApi = ref.read(walletApiProvider);
                  final session = await walletApi.beginTopUp(amount);
                  final RiderWalletTopUpFeedback feedback =
                      await finishRiderWalletTopUpCheckout(
                    walletApi: walletApi,
                    session: session,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(feedback.message)),
                    );
                  }
                  if (feedback.refreshImmediately) {
                    ref.invalidate(riderWalletLedgerProvider);
                    await ref
                        .read(riderSessionProvider.notifier)
                        .refreshWallet();
                  }
                  final int later = feedback.delayedRefreshes;
                  if (later > 0) {
                    unawaited(refreshWalletAfterTopUp(
                      times: later,
                      refresh: () => ref
                          .read(riderSessionProvider.notifier)
                          .refreshWallet(),
                    ));
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
            label: 'Transaction History',
            onPressed: () => context.push(RiderRoutes.ledger),
          ),
          const SizedBox(height: RiderSpacing.md),
          RiderSecondaryButton(
            label: 'Withdraw Money',
            onPressed: () {
              final bank = ref.read(riderBankProvider);
              unawaited(_amountSheet(
              context: context,
              ref: ref,
              title: 'Withdraw Money',
              confirmLabel: 'Withdraw',
              maxAmount: balance,
              upiSaved: bank.upiOnServer,
              bankSaved: bank.bankOnServer,
              onWithdraw: (amount, payoutMethod) async {
                await ref.read(walletApiProvider).withdraw(
                      amount: amount,
                      payoutMethod: payoutMethod,
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
              },
              ),
            );
            },
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
  FutureOr<void> Function(double amount)? onConfirm,
  FutureOr<void> Function(double amount, String payoutMethod)? onWithdraw,
  bool upiSaved = false,
  bool bankSaved = false,
  double? maxAmount,
}) {
  return _amountSheet(
    context: context,
    ref: ref,
    title: title,
    confirmLabel: confirmLabel,
    onConfirm: onConfirm,
    onWithdraw: onWithdraw,
    upiSaved: upiSaved,
    bankSaved: bankSaved,
    maxAmount: maxAmount,
  );
}

Future<void> _amountSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String confirmLabel,
  FutureOr<void> Function(double amount)? onConfirm,
  FutureOr<void> Function(double amount, String payoutMethod)? onWithdraw,
  bool upiSaved = false,
  bool bankSaved = false,
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
        onWithdraw: onWithdraw,
        upiSaved: upiSaved,
        bankSaved: bankSaved,
        maxAmount: maxAmount,
      );
    },
  );
}

class _WalletAmountSheet extends StatefulWidget {
  const _WalletAmountSheet({
    required this.title,
    required this.confirmLabel,
    this.onConfirm,
    this.onWithdraw,
    this.upiSaved = false,
    this.bankSaved = false,
    this.maxAmount,
  });

  final String title;
  final String confirmLabel;
  final FutureOr<void> Function(double amount)? onConfirm;
  final FutureOr<void> Function(double amount, String payoutMethod)? onWithdraw;
  final bool upiSaved;
  final bool bankSaved;
  final double? maxAmount;

  @override
  State<_WalletAmountSheet> createState() => _WalletAmountSheetState();
}

class _WalletAmountSheetState extends State<_WalletAmountSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  String? _error;
  String? _payoutMethod;
  bool _submitting = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _amountFocus.requestFocus();
  }

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
    final WithdrawalSubmission? submission = widget.onWithdraw == null
        ? null
        : withdrawalSubmission(
            amount: amount,
            payoutMethod: _payoutMethod,
            upiSaved: widget.upiSaved,
            bankSaved: widget.bankSaved,
          );
    if (widget.onWithdraw != null && submission == null) {
      setState(() {
        _error = withdrawalDestinationError(
          payoutMethod: _payoutMethod,
          upiSaved: widget.upiSaved,
          bankSaved: widget.bankSaved,
        );
      });
      return;
    }
    if (widget.onWithdraw != null && !_confirming) {
      setState(() {
        _confirming = true;
        _error = null;
      });
      return;
    }
    setState(() => _submitting = true);
    var closeSheet = false;
    try {
      if (submission != null) {
        await widget.onWithdraw!(submission.amount, submission.payoutMethod);
      } else {
        await widget.onConfirm!(amount);
      }
      closeSheet = true;
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = widget.onWithdraw != null
              ? 'Withdrawal could not be completed.'
              : 'That request could not be completed.';
        });
      }
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
          if (_confirming && widget.onWithdraw != null) ...[
            Text(
              'This withdrawal will be processed. The amount stays held until it is paid out.',
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: RiderSpacing.lg),
            _ConfirmLine(label: 'Requested withdrawal', value: formatInr(double.parse(_controller.text.trim()))),
            if (widget.maxAmount != null)
              _ConfirmLine(label: 'Available balance', value: formatInr(widget.maxAmount!)),
            _ConfirmLine(label: 'Withdrawal charge', value: formatInr(0)),
            Text(
              'No withdrawal charge.',
              style: RiderTextStyles.caption,
            ),
            _ConfirmLine(
              label: 'Final payable',
              value: formatInr(double.parse(_controller.text.trim())),
            ),
            if (_error != null) ...[
              const SizedBox(height: RiderSpacing.sm),
              Text(_error!, style: RiderTextStyles.caption.copyWith(color: RiderColors.error)),
            ],
          ] else ...[
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              textInputAction: TextInputAction.done,
              onTap: () => _amountFocus.requestFocus(),
              errorText: _error,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            if (widget.onWithdraw != null) ...[
              const SizedBox(height: RiderSpacing.lg),
              Text('Payout method', style: RiderTextStyles.caption),
              const SizedBox(height: RiderSpacing.sm),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('UPI'),
                    selected: _payoutMethod == 'UPI',
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() => _payoutMethod = 'UPI'),
                  ),
                  const SizedBox(width: RiderSpacing.sm),
                  ChoiceChip(
                    label: const Text('Bank'),
                    selected: _payoutMethod == 'BANK',
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() => _payoutMethod = 'BANK'),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: RiderSpacing.lg),
          if (_confirming && widget.onWithdraw != null && !_submitting)
            TextButton(
              onPressed: () => setState(() {
                _confirming = false;
                _error = null;
              }),
              child: const Text('Edit amount'),
            ),
          RiderPrimaryButton(
            label: _submitting
                ? 'Please wait…'
                : _confirming && widget.onWithdraw != null
                    ? 'Confirm withdrawal'
                    : widget.confirmLabel,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _ConfirmLine extends StatelessWidget {
  const _ConfirmLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: RiderTextStyles.caption)),
          Text(value, style: RiderTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
