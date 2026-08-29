import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:idhar_udhar/shared/api/api_exception.dart';

import '../../../../config/app_constants.dart';
import '../../../../core/animations/animations.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/widgets.dart';

/// Phone-only login — mobile number → OTP (dummy auth).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _fieldKey = GlobalKey();

  bool _isLoading = false;
  String? _phoneError;
  bool _navigating = false;
  bool _didAutofocus = false;

  static const int _phoneLength = 10;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(_onPhoneFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestAutofocus());
  }

  void _onPhoneFocus() {
    if (_phoneFocus.hasFocus) {
      _ensureFieldVisible();
    }
  }

  void _requestAutofocus() {
    if (!mounted || _didAutofocus) {
      return;
    }
    _didAutofocus = true;
    _phoneFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_phoneFocus.hasFocus) {
        _phoneFocus.requestFocus();
      }
      _ensureFieldVisible();
    });
  }

  void _ensureFieldVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final BuildContext? fieldContext = _fieldKey.currentContext;
      if (fieldContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.35,
      );
    });
  }

  @override
  void dispose() {
    _phoneFocus.removeListener(_onPhoneFocus);
    _phoneController.dispose();
    _phoneFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _validate() {
    final String phone = _phoneController.text.trim();
    String? phoneError;
    if (phone.isEmpty) {
      phoneError = 'Mobile number is required';
    } else if (phone.length != _phoneLength) {
      phoneError = 'Enter a valid 10-digit mobile number';
    }
    setState(() => _phoneError = phoneError);
    return phoneError == null;
  }

  Future<void> _onContinue() async {
    if (!_validate() || _isLoading || _navigating) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    if (!mounted || _navigating) {
      return;
    }

    final String phone = _phoneController.text.trim();
    ref.read(sessionProvider.notifier).startLogin(phone);
    try {
      await ref.read(sessionProvider.notifier).requestOtp();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      final String message = error is ApiException
          ? error.message
          : 'Could not send OTP. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted || _navigating) {
      return;
    }
    _navigating = true;
    setState(() => _isLoading = false);
    context.go(
      '${AppRoutes.otp}?phone=${Uri.encodeComponent('${AppConstants.defaultCountryCode}$phone')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool landscape = Responsive.isLandscape(context);
    final bool tablet = Responsive.isTablet(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bool keyboardOpen = keyboard > 0;
    final bool compact =
        landscape || size.height < 700 || keyboardOpen;
    final double hPad = Responsive.horizontalPadding(context);
    final double fieldH = compact ? 56 : 60;
    final double truckW = landscape
        ? (size.width * 0.22).clamp(110.0, 170.0)
        : (size.width * 0.42).clamp(140.0, 210.0);

    return Scaffold(
      // Body already shrinks for keyboard — do NOT also pad with viewInsets.
      resizeToAvoidBottomInset: true,
      body: AuthPremiumBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              controller: _scrollController,
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
                      FadeAnimation(
                        child: TopLogo(
                          alignment: Alignment.centerLeft,
                          height: compact ? 36 : 46,
                        ),
                      ),
                      if (!keyboardOpen) ...[
                        SizedBox(
                          height: compact ? AppSpacing.md : AppSpacing.lg,
                        ),
                        FadeAnimation(
                          delay: const Duration(milliseconds: 40),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: truckW,
                              child: const AspectRatio(
                                aspectRatio: 16 / 9,
                                child: SafeAssetImage(
                                  path: AssetPaths.bike,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                      FadeAnimation(
                        delay: const Duration(milliseconds: 80),
                        child: Text(
                          'Welcome Back!',
                          style: AppTextStyles.headingM.copyWith(
                            color: AppColors.navy,
                            fontSize: keyboardOpen ? 20 : null,
                          ),
                        ),
                      ),
                      if (!keyboardOpen) ...[
                        const SizedBox(height: AppSpacing.xs),
                        FadeAnimation(
                          delay: const Duration(milliseconds: 100),
                          child: Text.rich(
                            TextSpan(
                              style: AppTextStyles.headingL.copyWith(
                                color: AppColors.navy,
                                height: 1.15,
                              ),
                              children: const [
                                TextSpan(text: "Let's Get "),
                                TextSpan(
                                  text: 'Moving.',
                                  style: TextStyle(color: AppColors.orange),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FadeAnimation(
                          delay: const Duration(milliseconds: 120),
                          child: Text(
                            'Enter your mobile number to book a delivery in a few taps.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(
                        height: compact ? AppSpacing.md : AppSpacing.xxl,
                      ),
                      SlideAnimation(
                        delay: const Duration(milliseconds: 140),
                        child: RepaintBoundary(
                          child: GlassCard(
                            hero: true,
                            showAmbientGlow: true,
                            ambientColor: AppColors.orange,
                            padding: EdgeInsets.all(
                              compact ? AppSpacing.lg : AppSpacing.cardPadding,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Login with Mobile',
                                  style: AppTextStyles.headingS,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'We will send a one-time password (OTP)',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      compact ? AppSpacing.md : AppSpacing.xl,
                                ),
                                KeyedSubtree(
                                  key: _fieldKey,
                                  child: GlassTextField(
                                    controller: _phoneController,
                                    focusNode: _phoneFocus,
                                    hint: '10-digit mobile number',
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.done,
                                    height: fieldH,
                                    leadingIcon: Icons.phone_iphone_rounded,
                                    trailing: Text(
                                      AppConstants.defaultCountryCode,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(
                                        _phoneLength,
                                      ),
                                    ],
                                    autofillHints: const [
                                      AutofillHints.telephoneNumber,
                                    ],
                                    errorText: _phoneError,
                                    onChanged: (_) {
                                      if (_phoneError != null) {
                                        setState(() => _phoneError = null);
                                      }
                                    },
                                    onSubmitted: (_) => _onContinue(),
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      compact ? AppSpacing.md : AppSpacing.xl,
                                ),
                                AnimatedPrimaryButton(
                                  label: 'Continue',
                                  isLoading: _isLoading,
                                  onPressed: _onContinue,
                                ),
                                if (!keyboardOpen) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  Text(
                                    'By continuing you agree to IDHAR UDHAR Terms & Privacy.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
