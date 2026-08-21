import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/dummy_rider_data.dart';
import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/local/rider_permissions.dart';
import '../../routing/rider_otp_args.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_otp_input.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    this.mobile,
    this.flow = RiderAuthFlow.login,
  });

  final String? mobile;
  final RiderAuthFlow flow;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  String _otp = '';
  String? _error;
  bool _verifying = false;
  int _seconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_seconds <= 1) {
        t.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds -= 1);
      }
    });
  }

  Future<void> _verify() async {
    final repo = ref.read(dummyRiderRepositoryProvider);
    setState(() {
      _verifying = true;
      _error = null;
    });
    await repo.simulateLatency();
    if (!mounted) return;
    if (!repo.validateOtp(_otp)) {
      setState(() {
        _verifying = false;
        _error = 'Invalid OTP. Demo OTP is ${DummyRiderData.otp}';
      });
      return;
    }
    setState(() => _verifying = false);

    if (widget.flow == RiderAuthFlow.login) {
      await riderEnterAfterAuth(context);
    } else {
      // New rider registration continues onboarding.
      unawaited(context.push(RiderRoutes.profileSetup));
    }
  }

  void _resend() {
    if (_seconds > 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RiderColors.secondary,
        content: Text(
          'OTP resent (demo): ${DummyRiderData.otp}',
          style: RiderTextStyles.bodyMedium.copyWith(
            color: RiderColors.textOnPrimary,
          ),
        ),
      ),
    );
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = widget.mobile ?? DummyRiderData.defaultMobile;
    final isLogin = widget.flow == RiderAuthFlow.login;

    return RiderScaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login verification' : 'OTP verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: RiderPrimaryButton(
        label: _verifying
            ? 'Verifying…'
            : (isLogin ? 'Verify & Open Dashboard' : 'Verify & Continue'),
        enabled: !_verifying && _otp.length == 6,
        onPressed: _verify,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom > 0
                  ? RiderSpacing.md
                  : 0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: RiderSpacing.lg),
                  Text('Enter OTP', style: RiderTextStyles.heading),
                  const SizedBox(height: RiderSpacing.sm),
                  Text(
                    'Sent to $mobile',
                    style: RiderTextStyles.caption,
                  ),
                  const SizedBox(height: RiderSpacing.xl),
                  RiderGlassCard(
                    child: Column(
                      children: [
                        RiderOtpInput(
                          errorText: _error,
                          onChanged: (v) => setState(() {
                            _otp = v;
                            _error = null;
                          }),
                          onCompleted: (v) => setState(() => _otp = v),
                        ),
                        const SizedBox(height: RiderSpacing.xl),
                        Text(
                          _seconds > 0
                              ? 'Resend OTP in 00:${_seconds.toString().padLeft(2, '0')}'
                              : 'Didn’t receive the code?',
                          style: RiderTextStyles.caption,
                        ),
                        TextButton(
                          onPressed: _seconds == 0 ? _resend : null,
                          child: Text(
                            'Resend OTP',
                            style: RiderTextStyles.bodyMedium.copyWith(
                              color: _seconds == 0
                                  ? RiderColors.primary
                                  : RiderColors.hint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
