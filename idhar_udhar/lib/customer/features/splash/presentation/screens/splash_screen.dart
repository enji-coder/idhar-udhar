import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_config.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Premium splash — warm gradient canvas, logo, truck, route, loader.
///
/// After the sequence: restore local session → home (or profile setup) when
/// authenticated, otherwise login. Visual design unchanged.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _holdDuration = Duration(milliseconds: 3200);
  static const Duration _exitDuration = Duration(milliseconds: 320);

  late final AnimationController _master;
  late final AnimationController _truckBob;
  late final AnimationController _route;
  late final AnimationController _loader;
  late final AnimationController _exit;

  late final Animation<double> _bgFade;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _truckSlide;
  late final Animation<double> _truckFade;
  late final Animation<double> _copyFade;
  late final Animation<double> _loaderFade;
  late final Animation<double> _exitFade;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _truckBob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _route = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _exit = AnimationController(vsync: this, duration: _exitDuration);

    _bgFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
    );
    _logoFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.1, 0.42, curve: Curves.easeOutCubic),
    );
    _logoScale = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.1, 0.48, curve: Curves.easeOutCubic),
      ),
    );
    _truckFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.28, 0.6, curve: Curves.easeOutCubic),
    );
    _truckSlide = Tween<Offset>(
      begin: const Offset(0.1, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.28, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _copyFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.48, 0.75, curve: Curves.easeOut),
    );
    _loaderFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );
    _exitFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exit, curve: Curves.easeOutCubic),
    );

    _master.forward().then((_) {
      if (mounted) {
        _route.forward();
      }
    });
    _navTimer = Timer(_holdDuration, _finishAndGo);
  }

  Future<void> _finishAndGo() async {
    if (!mounted) {
      return;
    }
    // Restore persisted login while splash exit plays — avoid flashing Login.
    await ref.read(sessionProvider.notifier).hydrate();
    if (!mounted) {
      return;
    }
    await _exit.forward();
    if (!mounted) {
      return;
    }

    final SessionState session = ref.read(sessionProvider);
    if (session.isAuthenticated) {
      final bool needsName =
          ref.read(sessionProvider.notifier).needsProfileSetup;
      context.go(needsName ? AppRoutes.profileSetup : AppRoutes.home);
      return;
    }
    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _master.dispose();
    _truckBob.dispose();
    _route.dispose();
    _loader.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double shortest = size.shortestSide;
    final bool landscape = size.width > size.height;
    final double logoH = (shortest * 0.13).clamp(52.0, 84.0);
    final double truckW = landscape
        ? (size.width * 0.4).clamp(200.0, 360.0)
        : (size.width * 0.76).clamp(220.0, 400.0);

    return Scaffold(
      body: AuthPremiumBackground(
        safeArea: true,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _master,
            _truckBob,
            _route,
            _loader,
            _exit,
          ]),
          builder: (context, _) {
            final double bob = math.sin(_truckBob.value * math.pi) * 5;

            return Opacity(
              opacity: _exitFade.value,
              child: FadeTransition(
                opacity: _bgFade,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.06,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Column(
                            children: [
                              TopLogo(
                                alignment: Alignment.center,
                                stacked: true,
                                height: logoH,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                AppConfig.tagline,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.tagline.copyWith(
                                  fontSize:
                                      (shortest * 0.032).clamp(11.0, 14.0),
                                  color: AppColors.navyMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: landscape ? AppSpacing.lg : AppSpacing.xxl,
                      ),
                      FadeTransition(
                        opacity: _truckFade,
                        child: SlideTransition(
                          position: _truckSlide,
                          child: Transform.translate(
                            offset: Offset(0, bob),
                            child: SizedBox(
                              width: truckW,
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      bottom: 0,
                                      child: AmbientGlow.orange(
                                        diameter: truckW * 0.65,
                                        opacity: 0.22,
                                      ),
                                    ),
                                    CustomPaint(
                                      size: Size(truckW, truckW * 9 / 16),
                                      painter: _RouteArcPainter(
                                        progress: _route.value,
                                        color: AppColors.orange,
                                      ),
                                    ),
                                    FloatingAsset(
                                      path: AssetPaths.splashDeliveryTruck,
                                      width: truckW * 0.92,
                                      height: truckW * 9 / 16,
                                      showGlow: false,
                                      fallback: const _TruckFallback(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: landscape ? AppSpacing.md : AppSpacing.xl,
                      ),
                      FadeTransition(
                        opacity: _copyFade,
                        child: Text.rich(
                          TextSpan(
                            style: AppTextStyles.headingS.copyWith(
                              fontSize: (shortest * 0.04).clamp(14.0, 18.0),
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            children: const [
                              TextSpan(text: 'Fast. '),
                              TextSpan(
                                text: 'Safe.',
                                style: TextStyle(color: AppColors.orange),
                              ),
                              TextSpan(text: ' Reliable.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Spacer(flex: 3),
                      FadeTransition(
                        opacity: _loaderFade,
                        child: Column(
                          children: [
                            Text(
                              AppConfig.appName,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.navy,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _BrandProgressBar(
                              controller: _loader,
                              width: (size.width * 0.4).clamp(140.0, 220.0),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Loading…',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
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

class _BrandProgressBar extends StatelessWidget {
  const _BrandProgressBar({
    required this.controller,
    required this.width,
  });

  final AnimationController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    final double t = Curves.easeInOut.transform(controller.value);
    final double head = (t * 1.35).clamp(0.0, 1.0);

    return Semantics(
      label: 'Loading',
      child: Container(
        width: width,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.white.withOpacity(0.55),
          borderRadius: AppRadius.pillAll,
          boxShadow: AppShadows.soft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.35 + (head * 0.55),
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppGradients.primaryCtaSoft,
                borderRadius: AppRadius.pillAll,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteArcPainter extends CustomPainter {
  _RouteArcPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }

    final Path path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * -0.05,
        size.width * 0.88,
        size.height * 0.28,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    for (final PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..color = color.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      if (progress > 0.05) {
        final Tangent? tangent =
            metric.getTangentForOffset(metric.length * progress);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 4.5, Paint()..color = color);
          canvas.drawCircle(
            Offset(size.width * 0.12, size.height * 0.28),
            3.5,
            Paint()..color = AppColors.navy,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RouteArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _TruckFallback extends StatelessWidget {
  const _TruckFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.35),
        borderRadius: AppRadius.lgAll,
      ),
      child: const Center(
        child: Icon(
          Icons.local_shipping_rounded,
          size: 72,
          color: AppColors.orange,
        ),
      ),
    );
  }
}
