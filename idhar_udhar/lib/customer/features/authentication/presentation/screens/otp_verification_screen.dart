import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animations/animations.dart';
import '../../../../core/permissions/location_permission_service.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/widgets.dart';

/// Premium OTP verification — 4 glass boxes, timer, resend (dummy auth).
///
/// Visual design unchanged — input lifecycle fixes only.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    this.phoneNumber = '',
  });

  final String phoneNumber;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const int _otpLength = 4;
  static const int _resendSeconds = 30;

  final GlobalKey<OTPInputRowState> _otpKey = GlobalKey<OTPInputRowState>();
  final ValueNotifier<String> _otp = ValueNotifier<String>('');
  final ValueNotifier<int> _secondsLeft = ValueNotifier<int>(_resendSeconds);

  Timer? _timer;
  bool _verifying = false;
  bool _navigating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft.value = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft.value <= 1) {
        timer.cancel();
        _secondsLeft.value = 0;
        return;
      }
      _secondsLeft.value -= 1;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    _secondsLeft.dispose();
    super.dispose();
  }

  void _resetOtpBoxes() {
    _error = null;
    _otp.value = '';
    _otpKey.currentState?.clear();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onVerify() async {
    // Single-flight guard — ignore duplicate completion / button taps.
    if (_navigating || _verifying) {
      return;
    }

    final String code = _otp.value;
    // HARD RULE: never verify partial OTP (1, 12, 123).
    if (code.length != _otpLength) {
      return;
    }

    FocusScope.of(context).unfocus();
    // ignore: unawaited_futures
    HapticFeedback.lightImpact();
    setState(() {
      _verifying = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }

    final bool ok = ref.read(sessionProvider.notifier).verifyOtp(code);
    if (!ok) {
      setState(() {
        _verifying = false;
        _error = 'Invalid OTP. Please try again.';
      });
      _resetOtpBoxes();
      return;
    }

    final bool needsName = ref.read(sessionProvider.notifier).needsProfileSetup;
    final String nextRoute = await LocationPermissionService.routeAfterAuth(
      needsProfileSetup: needsName,
    );
    if (!mounted || _navigating) {
      return;
    }
    _navigating = true;
    setState(() => _verifying = false);
    context.go(nextRoute);
  }

  void _onResend() {
    if (_secondsLeft.value > 0 || _verifying) {
      return;
    }
    HapticFeedback.selectionClick();
    _resetOtpBoxes();
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'A new code was sent (demo). Use any $_otpLength digits.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String get _maskedPhone {
    final String raw = widget.phoneNumber.trim();
    if (raw.isEmpty) {
      return 'your number';
    }
    if (raw.length < 4) {
      return raw;
    }
    final String tail = raw.substring(raw.length - 4);
    return '${raw.substring(0, raw.length - 4).replaceAll(RegExp(r'\d'), '•')}$tail';
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool landscape = Responsive.isLandscape(context);
    final bool tablet = Responsive.isTablet(context);
    // NOTE: Do NOT branch the widget tree on keyboard open — that remounts
    // children, drops OTP focus, and looks like a verify/refresh.
    final bool compact = landscape || size.height < 700;
    final double hPad = Responsive.horizontalPadding(context);
    final double fieldH = compact ? 56 : 60;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuthPremiumBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                hPad,
                compact ? AppSpacing.sm : AppSpacing.xl,
                hPad,
                AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Responsive.constrain(
                  maxWidth: tablet ? 480 : Responsive.contentMaxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SecondaryButton(
                          label: 'Back',
                          showLeadingArrow: true,
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            context.go(AppRoutes.login);
                          },
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: compact ? AppSpacing.sm : AppSpacing.xl,
                      ),
                      FadeAnimation(
                        child: TopLogo(
                          alignment: Alignment.center,
                          height: compact
                              ? AppSpacing.logoMark
                              : AppSpacing.topLogoHeight,
                        ),
                      ),
                      SizedBox(
                        height: compact ? AppSpacing.lg : AppSpacing.xxl,
                      ),
                      SlideAnimation(
                        child: RepaintBoundary(
                          child: GlassCard(
                            hero: true,
                            blurSigma: 30,
                            opacity: 0.18,
                            borderWidth: 1.2,
                            borderColor: AppColors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(28),
                            showAmbientGlow: true,
                            ambientColor: AppColors.orange,
                            padding: EdgeInsets.all(
                              compact ? AppSpacing.lg : AppSpacing.xxl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    style: AppTextStyles.headingL.copyWith(
                                      color: AppColors.navy,
                                      fontSize: compact ? 22 : 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    children: const [
                                      TextSpan(text: 'Verify Your '),
                                      TextSpan(
                                        text: 'Number',
                                        style:
                                            TextStyle(color: AppColors.orange),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Enter the $_otpLength-digit code sent to $_maskedPhone',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(
                                  height:
                                      compact ? AppSpacing.lg : AppSpacing.xxl,
                                ),
                                ScaleAnimation(
                                  begin: 0.94,
                                  child: OTPInputRow(
                                    key: _otpKey,
                                    length: _otpLength,
                                    enabled: !_verifying,
                                    autofocus: true,
                                    onChanged: (value) {
                                      // Update code only — NEVER verify here.
                                      _otp.value = value;
                                      if (_error != null && mounted) {
                                        setState(() => _error = null);
                                      }
                                    },
                                    onCompleted: (value) {
                                      // Fires only when all 4 digits exist.
                                      if (value.length != _otpLength) {
                                        return;
                                      }
                                      _otp.value = value;
                                      _onVerify();
                                    },
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.lg),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      size: AppSpacing.iconSm,
                                      color: AppColors.orange
                                          .withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Flexible(
                                      child: Text(
                                        'Your verification code is encrypted and secure',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height:
                                      compact ? AppSpacing.lg : AppSpacing.xxl,
                                ),
                                ValueListenableBuilder<String>(
                                  valueListenable: _otp,
                                  builder: (context, code, _) {
                                    final bool canVerify =
                                        code.length == _otpLength &&
                                            !_verifying &&
                                            !_navigating;
                                    return AnimatedPrimaryButton(
                                      label: 'Verify',
                                      enabled: canVerify,
                                      isLoading: _verifying,
                                      height: fieldH,
                                      onPressed: canVerify ? _onVerify : null,
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                ValueListenableBuilder<int>(
                                  valueListenable: _secondsLeft,
                                  builder: (context, seconds, _) {
                                    return _ResendBlock(
                                      secondsLeft: seconds,
                                      canResend:
                                          seconds <= 0 && !_verifying,
                                      onResend: _onResend,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      FadeAnimation(
                        delay: AppMotion.normal,
                        child: GlassEffect(
                          depth: GlassDepthLevel.subtle,
                          blurSigma: 18,
                          opacity: 0.22,
                          borderWidth: 1,
                          borderColor:
                              AppColors.white.withValues(alpha: 0.45),
                          borderRadius: AppRadius.pillAll,
                          showInnerHighlight: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                color: AppColors.orange,
                                size: AppSpacing.iconMd,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  'We never share your OTP. IDHAR UDHAR is 100% safe.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ResendBlock extends StatelessWidget {
  const _ResendBlock({
    required this.secondsLeft,
    required this.canResend,
    required this.onResend,
  });

  final int secondsLeft;
  final bool canResend;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    if (canResend) {
      return Center(
        child: SecondaryButton(
          label: 'Resend OTP',
          onPressed: onResend,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.timer_outlined,
          size: AppSpacing.iconSm,
          color: AppColors.orange.withValues(alpha: 0.85),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              children: [
                const TextSpan(text: "Didn't receive the code? Resend in "),
                TextSpan(
                  text: '00:${secondsLeft.toString().padLeft(2, '0')}',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
