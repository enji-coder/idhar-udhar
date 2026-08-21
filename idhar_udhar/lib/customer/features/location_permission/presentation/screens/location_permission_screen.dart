import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/animations/animations.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../core/permissions/location_permission_service.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/custom_dialog.dart';

/// Location permission education + OS request (UI design unchanged).
///
/// Layout tightened so primary content + CTA fit common phone heights without
/// unnecessary scrolling (360×800 → 430×932).
class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _busy = false;

  void _goHome() {
    if (!mounted) {
      return;
    }
    context.go(AppRoutes.home);
  }

  Future<void> _onAllow() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final PermissionStatus current =
          await LocationPermissionService.status();

      if (current.isGranted || current.isLimited) {
        _goHome();
        return;
      }

      if (current.isPermanentlyDenied || current.isRestricted) {
        await _promptOpenSettings();
        return;
      }

      final PermissionStatus result =
          await LocationPermissionService.request();
      if (!mounted) {
        return;
      }

      if (result.isGranted || result.isLimited) {
        _goHome();
        return;
      }

      if (result.isPermanentlyDenied || result.isRestricted) {
        await _promptOpenSettings();
        return;
      }

      // Soft deny — continue without crashing or looping prompts.
      _goHome();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _promptOpenSettings() async {
    final bool? open = await CustomDialog.show(
      context: context,
      title: 'Location permission needed',
      message:
          'Location access is turned off for IDHAR UDHAR. You can enable it in system settings to find nearby riders.',
      confirmLabel: 'Open Settings',
      cancelLabel: 'Not Now',
    );
    if (!mounted) {
      return;
    }
    if (open == true) {
      await LocationPermissionService.openSettings();
    }
    _goHome();
  }

  void _onNotNow() {
    if (_busy) {
      return;
    }
    _goHome();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool landscape = Responsive.isLandscape(context);
    final bool compact = landscape || size.height < 780;
    final double artSize = landscape
        ? 110.0
        : (compact ? (size.height * 0.16).clamp(100.0, 140.0) : 180.0);
    final double hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      body: AuthPremiumBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: constraints.maxHeight < 640
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  compact ? AppSpacing.sm : AppSpacing.md,
                  hPad,
                  AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Responsive.constrain(
                    maxWidth: 520,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeAnimation(
                          child: TopLogo(
                            alignment: Alignment.center,
                            height: compact
                                ? AppSpacing.logoMark
                                : AppSpacing.topLogoHeight,
                          ),
                        ),
                        SizedBox(
                          height: compact ? AppSpacing.md : AppSpacing.lg,
                        ),
                        FloatingAnimation(
                          child: FadeAnimation(
                            child: Center(
                              child: FloatingAsset(
                                path: AssetPaths.locationPin,
                                width: artSize,
                                height: artSize * 0.9,
                                glowOpacity: 0.26,
                                fallback: Icon(
                                  Icons.location_on_rounded,
                                  size: artSize * 0.45,
                                  color: AppColors.orange,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: compact ? AppSpacing.md : AppSpacing.lg,
                        ),
                        SlideAnimation(
                          child: GlassCard(
                            hero: true,
                            borderRadius: BorderRadius.circular(28),
                            padding: EdgeInsets.all(
                              compact ? AppSpacing.lg : AppSpacing.xl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text.rich(
                                  AppTextStyles.mixedHeadline(
                                    navyPart: 'Enable ',
                                    orangePart: 'Location',
                                    base: AppTextStyles.headingL.copyWith(
                                      fontSize: compact ? 24 : null,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(
                                  height:
                                      compact ? AppSpacing.xs : AppSpacing.sm,
                                ),
                                Text(
                                  'We use your location to find nearby riders and show accurate pickup points.',
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: compact ? 13.5 : null,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(
                                  height:
                                      compact ? AppSpacing.md : AppSpacing.lg,
                                ),
                                FeatureCard(
                                  title: 'Faster pickups',
                                  subtitle: 'Detect your address instantly',
                                  icon: Icons.bolt_rounded,
                                  showChevron: true,
                                  compact: compact,
                                ),
                                SizedBox(
                                  height:
                                      compact ? AppSpacing.sm : AppSpacing.md,
                                ),
                                FeatureCard(
                                  title: 'Live tracking',
                                  subtitle: 'See riders moving toward you',
                                  icon: Icons.near_me_rounded,
                                  showChevron: true,
                                  compact: compact,
                                ),
                                SizedBox(
                                  height:
                                      compact ? AppSpacing.sm : AppSpacing.md,
                                ),
                                FeatureCard(
                                  title: 'Privacy first',
                                  subtitle: 'Only while you use the app',
                                  icon: Icons.shield_outlined,
                                  showChevron: true,
                                  compact: compact,
                                ),
                                SizedBox(
                                  height:
                                      compact ? AppSpacing.lg : AppSpacing.xl,
                                ),
                                AnimatedPrimaryButton(
                                  label: 'Allow Location',
                                  enabled: !_busy,
                                  isLoading: _busy,
                                  height: compact ? 50 : AppSpacing.buttonHeight,
                                  leading: const Icon(
                                    Icons.my_location_rounded,
                                    color: AppColors.white,
                                    size: AppSpacing.iconMd,
                                  ),
                                  onPressed: _busy ? null : _onAllow,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SecondaryButton(
                                  label: 'Not Now',
                                  enabled: !_busy,
                                  onPressed: _onNotNow,
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
      ),
    );
  }
}
