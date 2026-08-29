import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/local/rider_permissions.dart';
import '../data/local/rider_prefs.dart';
import '../routing/rider_routes.dart';
import '../state/rider_session.dart';
import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';
import '../widgets/rider_background.dart';
import '../widgets/rider_bike_visual.dart';
import '../widgets/rider_logo_widget.dart';

/// Rider splash — larger centered vehicle + journey loading → login.
/// Theme/colors intentionally unchanged. Existing image unchanged.
class RiderSplashScreen extends ConsumerStatefulWidget {
  const RiderSplashScreen({super.key});

  @override
  ConsumerState<RiderSplashScreen> createState() => _RiderSplashScreenState();
}

class _RiderSplashScreenState extends ConsumerState<RiderSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _idle;
  late final AnimationController _progress;
  late final AnimationController _loadingPulse;

  late final Animation<double> _bgFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _logoFade;
  late final Animation<double> _bikeAppear;
  late final Animation<double> _bikeYaw;
  late final Animation<double> _loadingFade;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _progressValue;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _loadingPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _bgFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.08, 0.38, curve: Curves.easeOutCubic),
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.08, 0.34, curve: Curves.easeOut),
    );

    _bikeAppear = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.30, 0.62, curve: Curves.easeOutCubic),
    );

    _bikeYaw = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -0.18, end: 0.10)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.10, end: 0.03)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.36, 0.78, curve: Curves.linear),
      ),
    );

    _loadingFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.58, 0.82, curve: Curves.easeOut),
    );

    _taglineFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.72, 0.95, curve: Curves.easeOut),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.72, 0.96, curve: Curves.easeOutCubic),
      ),
    );

    _progressValue = CurvedAnimation(
      parent: _progress,
      curve: Curves.easeInOutCubic,
    );

    _master.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _idle.repeat();
        _loadingPulse.repeat(reverse: true);
        _progress.forward();
      }
    });

    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future<void>.delayed(const Duration(milliseconds: 350), _goNext);
      }
    });

    _master.forward();
  }

  Future<void> _goNext() async {
    if (!mounted || _navigated) {
      return;
    }
    _navigated = true;
    try {
      final restored = await ref.read(riderSessionProvider.notifier).restore();
      if (!mounted) return;
      if (restored) {
        await riderGoHomeOrPermissionGate(context);
        return;
      }
      await RiderPrefs.clearLoggedIn();
      final setupDone = await RiderPrefs.isInitialSetupComplete();
      if (!mounted) return;
      context.go(setupDone ? RiderRoutes.login : RiderRoutes.terms);
    } catch (_) {
      if (!mounted) return;
      context.go(RiderRoutes.login);
    }
  }

  @override
  void dispose() {
    _master.dispose();
    _idle.dispose();
    _progress.dispose();
    _loadingPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RiderBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _bgFade,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double maxW = constraints.maxWidth;
                final double maxH = constraints.maxHeight;

                final double logoH = (maxW * 0.20).clamp(52.0, 80.0);
                // Larger, responsive vehicle — width-first so it fills the screen.
                final double bikeW = (maxW * 0.90).clamp(280.0, 560.0);
                final double bikeH = (maxH * 0.44).clamp(210.0, 360.0);

                return SizedBox(
                  width: maxW,
                  height: maxH,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RiderSpacing.screenH,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: RiderSpacing.lg),
                        Center(
                          child: SlideTransition(
                            position: _logoSlide,
                            child: FadeTransition(
                              opacity: _logoFade,
                              child: RiderLogoWidget(height: logoH),
                            ),
                          ),
                        ),
                        const SizedBox(height: RiderSpacing.sm),
                        // Center(
                        //   child: FadeTransition(
                        //     opacity: _logoFade,
                        //     child: Text(
                        //       'RIDER',
                        //       textAlign: TextAlign.center,
                        //       style: RiderTextStyles.caption.copyWith(
                        //         color: RiderColors.primary,
                        //         fontWeight: FontWeight.w700,
                        //         letterSpacing: 2.4,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        Expanded(
                          child: Center(
                            child: AnimatedBuilder(
                              animation: Listenable.merge(
                                <Listenable>[_master, _idle],
                              ),
                              builder: (context, _) {
                                final double settledSway = _master.isCompleted
                                    ? math.sin(_idle.value * math.pi * 2) *
                                        0.02
                                    : 0.0;
                                return RiderBikeVisual(
                                  appear: _bikeAppear.value,
                                  yaw: _bikeYaw.value + settledSway,
                                  idle: _idle.value,
                                  width: bikeW,
                                  height: bikeH,
                                );
                              },
                            ),
                          ),
                        ),
                        FadeTransition(
                          opacity: _loadingFade,
                          child: _RiderSplashLoading(
                            progress: _progressValue,
                            pulse: _loadingPulse,
                          ),
                        ),
                        const SizedBox(height: RiderSpacing.lg),
                        Center(
                          child: SlideTransition(
                            position: _taglineSlide,
                            child: FadeTransition(
                              opacity: _taglineFade,
                              child: Text(
                                'Deliver · Earn · Grow',
                                textAlign: TextAlign.center,
                                style: RiderTextStyles.bodyMedium.copyWith(
                                  color: RiderColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: RiderSpacing.xl),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact journey loading strip — uses existing Rider theme colors only.
class _RiderSplashLoading extends StatelessWidget {
  const _RiderSplashLoading({
    required this.progress,
    required this.pulse,
  });

  final Animation<double> progress;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[progress, pulse]),
      builder: (context, _) {
        final double p = progress.value.clamp(0.0, 1.0);
        final double pulseOpacity = 0.55 + (0.45 * pulse.value);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: RiderSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: pulseOpacity,
                child: Text(
                  'Loading your journey...',
                  textAlign: TextAlign.center,
                  style: RiderTextStyles.caption.copyWith(
                    color: RiderColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: RiderSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, barConstraints) {
                        final double trackW = barConstraints.maxWidth;
                        final double thumbX =
                            (trackW - 18) * p; // icon travel
                        return SizedBox(
                          height: 22,
                          width: trackW,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.centerLeft,
                            children: [
                              // Track
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: RiderColors.primary
                                        .withValues(alpha: 0.14),
                                    borderRadius: RiderRadius.pillAll,
                                  ),
                                ),
                              ),
                              // Fill
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: p,
                                  child: Container(
                                    height: 7,
                                    decoration: BoxDecoration(
                                      gradient: RiderColors.primaryGradient,
                                      borderRadius: RiderRadius.pillAll,
                                    ),
                                  ),
                                ),
                              ),
                              // Subtle scooter marker along progress
                              Positioned(
                                left: thumbX,
                                top: 0,
                                child: const Icon(
                                  Icons.delivery_dining_rounded,
                                  size: 18,
                                  color: RiderColors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
