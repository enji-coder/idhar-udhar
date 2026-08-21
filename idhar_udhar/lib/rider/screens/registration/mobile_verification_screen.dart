import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/dummy_rider_data.dart';
import '../../routing/rider_otp_args.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_text_field.dart';

class MobileVerificationScreen extends StatefulWidget {
  const MobileVerificationScreen({super.key, this.initialMobile});

  final String? initialMobile;

  @override
  State<MobileVerificationScreen> createState() =>
      _MobileVerificationScreenState();
}

class _MobileVerificationScreenState extends State<MobileVerificationScreen> {
  late final TextEditingController _phone;
  bool _editing = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialMobile ?? DummyRiderData.defaultMobileDigits;
    _phone = TextEditingController(
      text: seed.replaceAll(RegExp(r'\D'), '').length == 10
          ? seed.replaceAll(RegExp(r'\D'), '')
          : DummyRiderData.defaultMobileDigits,
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _displayMobile {
    final d = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (d.length == 10) {
      return '+91 ${d.substring(0, 5)} ${d.substring(5)}';
    }
    return '+91 $d';
  }

  Future<void> _sendOtp() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _sending = false);
    unawaited(
      context.push(
        RiderRoutes.otpVerification,
        extra: RiderOtpArgs(
          mobile: _displayMobile,
          flow: RiderAuthFlow.registration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Mobile verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: RiderPrimaryButton(
        label: _sending ? 'Sending…' : 'Send OTP',
        enabled: !_sending,
        onPressed: _sendOtp,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: RiderSpacing.xl),
            Text('Verify your number', style: RiderTextStyles.heading),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'We will send a one-time password to confirm this mobile number.',
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_editing) ...[
                    Text('Mobile number', style: RiderTextStyles.bodyMedium),
                    const SizedBox(height: RiderSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          color: RiderColors.primary,
                        ),
                        const SizedBox(width: RiderSpacing.md),
                        Expanded(
                          child: Text(
                            _displayMobile,
                            style: RiderTextStyles.title,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _editing = true),
                          child: Text(
                            'Edit',
                            style: RiderTextStyles.bodyMedium.copyWith(
                              color: RiderColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    RiderTextField(
                      controller: _phone,
                      label: 'Mobile number',
                      hint: '10-digit mobile number',
                      prefixIcon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      errorText: _error,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _editing = false),
                        child: Text(
                          'Done',
                          style: RiderTextStyles.bodyMedium.copyWith(
                            color: RiderColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
