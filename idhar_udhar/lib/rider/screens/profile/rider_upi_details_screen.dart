import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_secondary_button.dart';
import '../../widgets/rider_text_field.dart';

/// Dedicated Rider UPI details — local/session save only (no backend).
class RiderUpiDetailsScreen extends ConsumerStatefulWidget {
  const RiderUpiDetailsScreen({super.key});

  @override
  ConsumerState<RiderUpiDetailsScreen> createState() =>
      _RiderUpiDetailsScreenState();
}

class _RiderUpiDetailsScreenState extends ConsumerState<RiderUpiDetailsScreen> {
  late final TextEditingController _upi;
  late bool _editing;
  String? _upiError;

  static final RegExp _upiPattern = RegExp(
    r'^[a-zA-Z0-9._-]{2,}@[a-zA-Z][a-zA-Z0-9.-]{2,}$',
  );

  @override
  void initState() {
    super.initState();
    final existing = ref.read(riderBankProvider).upiId.trim();
    _upi = TextEditingController(text: existing);
    _editing = existing.isEmpty;
  }

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  String? _validate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Enter your UPI ID';
    if (!_upiPattern.hasMatch(value)) {
      return 'Enter a valid UPI ID (example: name@upi)';
    }
    return null;
  }

  void _save() {
    final error = _validate(_upi.text);
    setState(() => _upiError = error);
    if (error != null) return;

    final current = ref.read(riderBankProvider);
    final hasExisting = current.upiId.trim().isNotEmpty;
    ref.read(riderBankProvider.notifier).state = current.copyWith(
      upiId: _upi.text.trim(),
      upiVerified: true,
    );
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RiderColors.secondary,
        content: Text(
          hasExisting
              ? 'UPI ID updated successfully'
              : 'UPI ID added successfully',
          style: RiderTextStyles.bodyMedium.copyWith(
            color: RiderColors.textOnPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: RiderColors.surface,
          shape: RoundedRectangleBorder(borderRadius: RiderRadius.lgAll),
          title: Text('Delete UPI ID', style: RiderTextStyles.title),
          content: Text(
            'Are you sure you want to delete this UPI ID?',
            style: RiderTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: RiderTextStyles.bodyMedium.copyWith(
                  color: RiderColors.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: RiderTextStyles.bodyMedium.copyWith(
                  color: RiderColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    _delete();
  }

  void _delete() {
    final current = ref.read(riderBankProvider);
    ref.read(riderBankProvider.notifier).state = current.copyWith(
      upiId: '',
      upiVerified: false,
    );
    _upi.clear();
    setState(() {
      _editing = true;
      _upiError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(riderBankProvider);
    final hasUpi = bank.upiId.trim().isNotEmpty;

    return RiderScaffold(
      appBar: AppBar(
        title: const Text('UPI Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          RiderGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RiderTextField(
                  controller: _upi,
                  label: 'UPI ID',
                  hint: 'name@upi',
                  prefixIcon: Icons.currency_rupee_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  readOnly: !_editing,
                  errorText: _upiError,
                  onChanged: (_) {
                    if (_upiError != null) {
                      setState(() => _upiError = null);
                    }
                  },
                ),
                const SizedBox(height: RiderSpacing.xl),
                if (_editing)
                  RiderPrimaryButton(
                    label: hasUpi ? 'Save UPI' : 'Add UPI',
                    onPressed: _save,
                  )
                else
                  RiderSecondaryButton(
                    label: 'Edit UPI',
                    onPressed: () => setState(() {
                      _editing = true;
                      _upiError = null;
                    }),
                  ),
                if (hasUpi) ...[
                  const SizedBox(height: RiderSpacing.md),
                  RiderSecondaryButton(
                    label: 'Delete UPI',
                    destructive: true,
                    onPressed: _confirmDelete,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
