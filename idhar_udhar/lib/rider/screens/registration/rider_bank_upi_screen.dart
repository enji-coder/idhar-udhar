import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/api/api_providers.dart';
import '../../data/dummy/dummy_rider_repository.dart';
import '../../state/rider_payout_destination.dart';
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
  String? _bankError;
  String? _holderError;
  String? _accountError;
  String? _ifscError;

  @override
  void initState() {
    super.initState();
    final b = ref.read(riderBankProvider);
    _bankName = TextEditingController(text: b.bankName);
    _holder = TextEditingController(text: b.accountHolder);
    _account = TextEditingController(text: b.accountNumber);
    _ifsc = TextEditingController(text: b.ifsc);
  }

  @override
  void dispose() {
    _bankName.dispose();
    _holder.dispose();
    _account.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  bool _validate() {
    final BankFieldErrors errors = validateBankFields(
      bankName: _bankName.text,
      holderName: _holder.text,
      accountNumber: _account.text,
      ifsc: _ifsc.text,
    );
    setState(() {
      _bankError = errors.bankName;
      _holderError = errors.holder;
      _accountError = errors.account;
      _ifscError = errors.ifsc;
    });
    return errors.isValid;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    final current = ref.read(riderBankProvider);
    try {
      final saved = await persistBankDestination(
        saveBank: ref.read(walletApiProvider).saveBank,
        current: current,
        bankName: _bankName.text,
        holderName: _holder.text,
        accountNumber: _account.text,
        ifsc: _ifsc.text,
      );
      if (!mounted) return;
      ref.read(riderBankProvider.notifier).state = saved;
      if (widget.editMode) {
        context.pop();
        return;
      }
      context.push(RiderRoutes.verificationStatus);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
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
              'Add the bank account for your earnings. Save a UPI ID separately.',
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                children: [
                  RiderTextField(
                    controller: _bankName,
                    label: 'Bank name',
                    hint: 'Bank name',
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
                    hint: 'IFSC code',
                    prefixIcon: Icons.qr_code_rounded,
                    errorText: _ifscError,
                    textInputAction: TextInputAction.done,
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
