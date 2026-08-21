import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_text_field.dart';

class RiderBankUpiScreen extends ConsumerStatefulWidget {
  const RiderBankUpiScreen({
    super.key,
    this.editMode = false,
  });

  final bool editMode;

  @override
  ConsumerState<RiderBankUpiScreen> createState() => _RiderBankUpiScreenState();
}

class _RiderBankUpiScreenState extends ConsumerState<RiderBankUpiScreen> {
  late final TextEditingController _bankName;
  late final TextEditingController _holder;
  late final TextEditingController _account;
  late final TextEditingController _ifsc;
  late final TextEditingController _upi;
  String? _bankError;
  String? _holderError;
  String? _accountError;
  String? _ifscError;
  String? _upiError;

  @override
  void initState() {
    super.initState();
    final b = ref.read(riderBankProvider);
    _bankName = TextEditingController(text: b.bankName);
    _holder = TextEditingController(text: b.accountHolder);
    _account = TextEditingController(text: b.accountNumber);
    _ifsc = TextEditingController(text: b.ifsc);
    _upi = TextEditingController(text: b.upiId);
  }

  @override
  void dispose() {
    _bankName.dispose();
    _holder.dispose();
    _account.dispose();
    _ifsc.dispose();
    _upi.dispose();
    super.dispose();
  }

  bool _validate() {
    String? bankError;
    String? holderError;
    String? accountError;
    String? ifscError;
    String? upiError;
    if (_bankName.text.trim().length < 3) {
      bankError = 'Enter bank name';
    }
    if (_holder.text.trim().length < 3) {
      holderError = 'Enter account holder name';
    }
    final acc = _account.text.replaceAll(RegExp(r'\s'), '');
    if (acc.length < 8) {
      accountError = 'Enter a valid account number';
    }
    if (_ifsc.text.trim().length < 8) {
      ifscError = 'Enter a valid IFSC';
    }
    if (!_upi.text.contains('@')) {
      upiError = 'Enter a valid UPI ID';
    }
    setState(() {
      _bankError = bankError;
      _holderError = holderError;
      _accountError = accountError;
      _ifscError = ifscError;
      _upiError = upiError;
    });
    return bankError == null &&
        holderError == null &&
        accountError == null &&
        ifscError == null &&
        upiError == null;
  }

  void _save() {
    if (!_validate()) return;
    final current = ref.read(riderBankProvider);
    ref.read(riderBankProvider.notifier).state = current.copyWith(
      bankName: _bankName.text.trim(),
      accountHolder: _holder.text.trim(),
      accountNumber: _account.text.replaceAll(RegExp(r'\s'), ''),
      ifsc: _ifsc.text.trim().toUpperCase(),
      upiId: _upi.text.trim(),
    );
    if (widget.editMode) {
      context.pop();
      return;
    }
    context.push(RiderRoutes.verificationStatus);
  }

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: Text(widget.editMode ? 'Edit bank details' : 'Bank / UPI details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: RiderPrimaryButton(
        label: widget.editMode ? 'Save' : 'Continue',
        onPressed: _save,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.editMode ? 'Update payout details' : 'Where should we send earnings?',
              style: RiderTextStyles.heading,
            ),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'Dummy local data only — no real bank transfer in this build.',
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                children: [
                  RiderTextField(
                    controller: _bankName,
                    label: 'Bank name',
                    hint: 'HDFC Bank',
                    prefixIcon: Icons.account_balance_outlined,
                    errorText: _bankError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _holder,
                    label: 'Account holder',
                    hint: 'Name as per bank',
                    prefixIcon: Icons.person_outline_rounded,
                    errorText: _holderError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _account,
                    label: 'Account number',
                    hint: 'Account number',
                    prefixIcon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    errorText: _accountError,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _ifsc,
                    label: 'IFSC',
                    hint: 'HDFC0001234',
                    prefixIcon: Icons.qr_code_rounded,
                    errorText: _ifscError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _upi,
                    label: 'UPI ID',
                    hint: 'name@okhdfc',
                    prefixIcon: Icons.currency_rupee_rounded,
                    errorText: _upiError,
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
