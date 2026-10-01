import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

/// Receiver contact for this booking. It is not the customer login number.
class ReceiverDetailsScreen extends ConsumerStatefulWidget {
  const ReceiverDetailsScreen({super.key});

  @override
  ConsumerState<ReceiverDetailsScreen> createState() =>
      _ReceiverDetailsScreenState();
}

class _ReceiverDetailsScreenState extends ConsumerState<ReceiverDetailsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  String? _nameError;
  String? _mobileError;

  @override
  void initState() {
    super.initState();
    final BookingDraft draft = ref.read(bookingDraftProvider);
    _name = TextEditingController(text: draft.receiverName);
    _mobile = TextEditingController(text: draft.receiverMobile);
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  void _continue() {
    final String? nameError = BookingDraft.receiverNameError(_name.text);
    final String? mobileError = BookingDraft.receiverMobileError(_mobile.text);
    setState(() {
      _nameError = nameError;
      _mobileError = mobileError;
    });
    if (nameError != null || mobileError != null) {
      return;
    }
    ref.read(bookingDraftProvider.notifier).setReceiver(
          name: _name.text,
          mobile: _mobile.text,
        );
    context.push(AppRoutes.bookPackage);
  }

  @override
  Widget build(BuildContext context) {
    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Continue',
        onPressed: _continue,
      ),
      child: ListView(
        children: [
          Row(
            children: [
              const IuBackButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Receiver Details',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Who should receive this delivery?',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassTextField(
            controller: _name,
            label: "Receiver's name",
            hint: 'Full name',
            leadingIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            errorText: _nameError,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_nameError != null) {
                setState(() => _nameError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          GlassTextField(
            controller: _mobile,
            label: "Receiver's mobile number",
            hint: '10-digit mobile number',
            leadingIcon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            errorText: _mobileError,
            trailing: Text(
              AppConstants.defaultCountryCode,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) {
              if (_mobileError != null) {
                setState(() => _mobileError = null);
              }
            },
            onSubmitted: (_) => _continue(),
          ),
        ],
      ),
    );
  }
}
