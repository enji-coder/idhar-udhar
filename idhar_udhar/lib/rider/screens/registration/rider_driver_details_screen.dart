import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/local/rider_permissions.dart';
import '../../routing/rider_routes.dart';
import '../../state/rider_session.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_text_field.dart';

class RiderDriverDetailsScreen extends ConsumerStatefulWidget {
  const RiderDriverDetailsScreen({super.key});

  @override
  ConsumerState<RiderDriverDetailsScreen> createState() =>
      _RiderDriverDetailsScreenState();
}

class _RiderDriverDetailsScreenState
    extends ConsumerState<RiderDriverDetailsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _dob;
  late final TextEditingController _license;
  String? _nameError;
  String? _mobileError;
  String? _licenseError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final stored = ref.read(riderDriverProvider);
    final String sessionDigits = riderPhoneDigits(
      ref.read(riderSessionProvider).phone,
    );
    final String storedDigits = riderPhoneDigits(stored.mobile);
    _name = TextEditingController(text: stored.fullName);
    _mobile = TextEditingController(
      text: storedDigits.length == 10
          ? storedDigits
          : (sessionDigits.length == 10 ? sessionDigits : ''),
    );
    _dob = TextEditingController(text: stored.dateOfBirthLabel);
    _license = TextEditingController(text: stored.licenseNumber);
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _dob.dispose();
    _license.dispose();
    super.dispose();
  }

  bool _validate() {
    String? nameError;
    String? mobileError;
    String? licenseError;
    if (_name.text.trim().length < 3) {
      nameError = 'Enter the driver full name';
    }
    final digits = _mobile.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      mobileError = 'Enter a valid 10-digit mobile number';
    }
    if (_license.text.trim().length < 8) {
      licenseError = 'Enter a valid driving licence number';
    }
    setState(() {
      _nameError = nameError;
      _mobileError = mobileError;
      _licenseError = licenseError;
    });
    return nameError == null && mobileError == null && licenseError == null;
  }

  Future<void> _pickDob() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dob.text = DateFormat('dd MMM yyyy').format(picked);
    });
  }

  Future<void> _continue() async {
    if (_saving || !_validate()) return;
    DateTime? dob;
    if (_dob.text.trim().isNotEmpty) {
      try {
        dob = DateFormat('dd MMM yyyy').parse(_dob.text.trim());
      } catch (_) {
        dob = null;
      }
    }
    setState(() => _saving = true);
    try {
      await ref.read(riderSessionProvider.notifier).updateProfile(
            name: _name.text.trim(),
            dateOfBirth: dob,
            drivingLicence: _license.text.trim(),
          );
      if (!mounted) return;
      final session = ref.read(riderSessionProvider);
      if (session.onboardingResume) {
        await riderEnterAfterAuth(context, ref);
        return;
      }
      unawaited(context.push(RiderRoutes.documents));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver details could not be saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Driver details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: RiderPrimaryButton(
        label: _saving ? 'Saving' : 'Continue',
        onPressed: _saving ? null : _continue,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rider / driver information', style: RiderTextStyles.heading),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'Enter details of the person who will make deliveries.',
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                children: [
                  RiderTextField(
                    controller: _name,
                    label: 'Full name',
                    hint: 'Driver name',
                    prefixIcon: Icons.badge_outlined,
                    errorText: _nameError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _mobile,
                    label: 'Mobile',
                    hint: '10-digit mobile number',
                    prefixIcon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    enabled: false,
                    readOnly: true,
                    maxLength: 10,
                    errorText: _mobileError,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _dob,
                    label: 'Date of birth',
                    hint: 'Select date of birth',
                    prefixIcon: Icons.calendar_month_rounded,
                    readOnly: true,
                    onTap: _pickDob,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _license,
                    label: 'Driving licence number',
                    hint: 'Driving licence number',
                    prefixIcon: Icons.credit_card_rounded,
                    errorText: _licenseError,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
