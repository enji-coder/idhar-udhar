import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  String? _emailError;
  bool _saving = false;

  static final RegExp _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).user;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    final String value = _email.text.trim();
    if (value.isEmpty) {
      if (_emailError != null) {
        setState(() => _emailError = null);
      }
      return true;
    }
    if (!_emailRegex.hasMatch(value)) {
      setState(() => _emailError = 'Enter a valid email address');
      return false;
    }
    if (_emailError != null) {
      setState(() => _emailError = null);
    }
    return true;
  }

  void _save() {
    if (_saving) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_validateEmail()) {
      _emailFocus.requestFocus();
      return;
    }
    _saving = true;
    ref.read(sessionProvider.notifier).setName(_name.text);
    ref.read(sessionProvider.notifier).setEmail(_email.text.trim());
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Watch phone only — avoid rebuilding fields on unrelated session noise.
    final phone = ref.watch(
      sessionProvider.select((s) => s.user?.phone ?? ''),
    );

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Save',
        onPressed: _save,
      ),
      child: ListView(
        // Do not dismiss keyboard on drag — avoids focus flicker while editing.
        children: [
          Row(
            children: [
              const IuBackButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Edit Profile',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassTextField(
                  controller: _name,
                  focusNode: _nameFocus,
                  hint: 'Full name',
                  leadingIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _emailFocus.requestFocus(),
                ),
                const SizedBox(height: AppSpacing.lg),
                GlassTextField(
                  controller: _email,
                  focusNode: _emailFocus,
                  hint: 'Email for invoicing',
                  leadingIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(80),
                  ],
                  errorText: _emailError,
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  },
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Used for invoices only. Optional for now.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  borderRadius: AppRadius.lgAll,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.phone_iphone_rounded,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mobile number',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(phone, style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Mobile number is verified via OTP and cannot be edited here.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
