import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';

import '../routing/rider_otp_args.dart';
import '../routing/rider_routes.dart';
import '../state/rider_session.dart';
import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';
import '../widgets/rider_background.dart';
import '../widgets/rider_glass_card.dart';
import '../widgets/rider_logo_widget.dart';
import '../widgets/rider_primary_button.dart';
import '../widgets/rider_text_field.dart';

/// Rider login — phone-only dummy flow (no social / no backend).
class RiderLoginScreen extends ConsumerStatefulWidget {
  const RiderLoginScreen({super.key});

  @override
  ConsumerState<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends ConsumerState<RiderLoginScreen> {
  final TextEditingController _phone = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool _validate() {
    final String digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      setState(() => _error = 'Enter your mobile number');
      return false;
    }
    if (digits.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  Future<void> _continue() async {
    if (_submitting) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_validate()) {
      return;
    }
    setState(() => _submitting = true);
    final String digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    try {
      await ref.read(riderSessionProvider.notifier).requestOtp(digits);
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      context.go(
        RiderRoutes.otpVerification,
        extra: RiderOtpArgs(
          mobile: digits,
          flow: RiderAuthFlow.login,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = 'Could not send OTP. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double logoH = (size.width * 0.18).clamp(48.0, 72.0);
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: RiderBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  RiderSpacing.screenH,
                  RiderSpacing.xl,
                  RiderSpacing.screenH,
                  RiderSpacing.xl + viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - RiderSpacing.xl * 2,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: RiderSpacing.md),
                        Center(child: RiderLogoWidget(height: logoH)),
                        const SizedBox(height: RiderSpacing.sm),
                        Text(
                          'PARTNER',
                          textAlign: TextAlign.center,
                          style: RiderTextStyles.caption.copyWith(
                            color: RiderColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: RiderSpacing.xxl),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: RiderTextStyles.heading,
                        ),
                        const SizedBox(height: RiderSpacing.sm),
                        Text(
                          'Sign in with your mobile number to start delivering',
                          textAlign: TextAlign.center,
                          style: RiderTextStyles.caption,
                        ),
                        const SizedBox(height: RiderSpacing.xxl),
                        RiderGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              RiderTextField(
                                controller: _phone,
                                label: 'Mobile number',
                                hint: '10-digit mobile number',
                                prefixIcon: Icons.phone_rounded,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                maxLength: 10,
                                errorText: _error,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                              ),
                              const SizedBox(height: RiderSpacing.xl),
                              RiderPrimaryButton(
                                label: _submitting
                                    ? 'Please wait…'
                                    : 'Continue',
                                enabled: !_submitting,
                                onPressed: _continue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: RiderSpacing.lg),
                        TextButton(
                          onPressed: () =>
                              context.push(RiderRoutes.registrationWelcome),
                          child: Text.rich(
                            TextSpan(
                              style: RiderTextStyles.caption,
                              children: [
                                const TextSpan(text: "Don't have an account? "),
                                TextSpan(
                                  text: 'Register now',
                                  style: RiderTextStyles.caption.copyWith(
                                    color: RiderColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: RiderSpacing.xl),
                        Text(
                          'By continuing you agree to IDHAR UDHAR PARTNER terms.',
                          textAlign: TextAlign.center,
                          style: RiderTextStyles.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
