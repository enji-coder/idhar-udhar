import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animations/animations.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../core/permissions/location_permission_service.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/widgets.dart';

/// First-time profile — collect customer name only.
///
/// Visual design unchanged — behavior/flow fixes only.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final ValueNotifier<bool> _isValid = ValueNotifier<bool>(false);
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _fieldKey = GlobalKey();

  String? _error;
  bool _loading = false;
  bool _navigating = false;
  bool _didAutofocus = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _nameFocus.addListener(_onNameFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestAutofocus());
  }

  void _onNameChanged() {
    final bool valid = _nameController.text.trim().length >= 2;
    if (_isValid.value != valid) {
      _isValid.value = valid;
    }
  }

  void _onNameFocus() {
    if (_nameFocus.hasFocus) {
      _ensureFieldVisible();
    }
  }

  void _requestAutofocus() {
    if (!mounted || _didAutofocus) {
      return;
    }
    _didAutofocus = true;
    _nameFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_nameFocus.hasFocus) {
        _nameFocus.requestFocus();
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
    _nameController.removeListener(_onNameChanged);
    _nameFocus.removeListener(_onNameFocus);
    _nameController.dispose();
    _nameFocus.dispose();
    _isValid.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final String name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Please enter your name');
      _nameFocus.requestFocus();
      return;
    }
    if (_loading || _navigating) {
      return;
    }

    FocusScope.of(context).unfocus();
    // ignore: unawaited_futures
    HapticFeedback.lightImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    ref.read(sessionProvider.notifier).setName(name);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final String nextRoute = await LocationPermissionService.routeAfterAuth(
      needsProfileSetup: false,
    );
    if (!mounted || _navigating) {
      return;
    }
    _navigating = true;
    context.go(nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bool keyboardOpen = keyboard > 0;
    final bool compact = size.height < 700 || keyboardOpen;
    final String phone = ref.watch(sessionProvider).user?.phone ?? '';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuthPremiumBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  Responsive.horizontalPadding(context),
                  AppSpacing.md,
                  Responsive.horizontalPadding(context),
                  AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Responsive.constrain(
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
                              context.go(AppRoutes.otp);
                            },
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                        ),
                        if (!keyboardOpen) ...[
                          const SizedBox(height: AppSpacing.md),
                          const TopLogo(alignment: Alignment.center),
                          SizedBox(
                            height: compact ? AppSpacing.lg : AppSpacing.xxl,
                          ),
                          FadeAnimation(
                            child: Center(
                              child: SafeAssetImage(
                                path: AssetPaths.rider,
                                height: compact ? 140 : 180,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: compact ? AppSpacing.lg : AppSpacing.xxl,
                          ),
                        ] else
                          const SizedBox(height: AppSpacing.md),
                        SlideAnimation(
                          child: RepaintBoundary(
                            child: GlassCard(
                              hero: true,
                              showAmbientGlow: true,
                              ambientColor: AppColors.orange,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      style: AppTextStyles.headingM,
                                      children: const [
                                        TextSpan(text: 'What should we '),
                                        TextSpan(
                                          text: 'call you?',
                                          style: TextStyle(
                                            color: AppColors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    phone.isEmpty
                                        ? 'Complete your profile to start booking.'
                                        : 'Signed in as $phone',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  KeyedSubtree(
                                    key: _fieldKey,
                                    child: GlassTextField(
                                      controller: _nameController,
                                      focusNode: _nameFocus,
                                      hint: 'Your full name',
                                      leadingIcon: Icons.person_outline_rounded,
                                      textInputAction: TextInputAction.done,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(40),
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r"[a-zA-Z\s'.-]"),
                                        ),
                                      ],
                                      errorText: _error,
                                      onChanged: (_) {
                                        if (_error != null) {
                                          setState(() => _error = null);
                                        }
                                      },
                                      onSubmitted: (_) {
                                        if (_isValid.value) {
                                          _continue();
                                        } else {
                                          setState(
                                            () => _error =
                                                'Please enter your name',
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _isValid,
                                    builder: (context, valid, _) {
                                      return AnimatedPrimaryButton(
                                        label: 'Continue',
                                        isLoading: _loading,
                                        enabled: valid && !_loading,
                                        onPressed: valid && !_loading
                                            ? _continue
                                            : null,
                                      );
                                    },
                                  ),
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
      ),
    );
  }
}
