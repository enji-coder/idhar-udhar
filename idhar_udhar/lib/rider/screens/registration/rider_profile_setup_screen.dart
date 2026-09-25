import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../routing/rider_routes.dart';
import '../../state/rider_session.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_bottom_sheet.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_text_field.dart';

const List<String> _languages = <String>['English', 'Hindi', 'Gujarati'];

class RiderProfileSetupScreen extends ConsumerStatefulWidget {
  const RiderProfileSetupScreen({super.key});

  @override
  ConsumerState<RiderProfileSetupScreen> createState() =>
      _RiderProfileSetupScreenState();
}

class _RiderProfileSetupScreenState
    extends ConsumerState<RiderProfileSetupScreen> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _dob;
  String? _language;
  DateTime? _dobDate;
  String? _photoPath;
  String? _nameError;
  String? _emailError;
  String? _dobError;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(riderProfileStateProvider);
    final String phone = formatRiderPhone(
      profile.mobile.isNotEmpty
          ? profile.mobile
          : ref.read(riderSessionProvider).phone,
    );
    _name = TextEditingController(text: profile.name);
    _mobile = TextEditingController(text: phone);
    _email = TextEditingController(text: profile.email);
    _dobDate = profile.dateOfBirth;
    _dob = TextEditingController(
      text: _dobDate == null
          ? ''
          : DateFormat('dd MMM yyyy').format(_dobDate!),
    );
    _language = profile.language.trim().isEmpty ? null : profile.language;
    _photoPath = profile.photoUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _dob.dispose();
    super.dispose();
  }

  bool _validate() {
    String? nameError;
    String? emailError;
    String? dobError;
    if (_name.text.trim().length < 3) {
      nameError = 'Enter your full name';
    }
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      emailError = 'Enter a valid email';
    }
    if (_dob.text.trim().isEmpty) {
      dobError = 'Select date of birth';
    }
    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _dobError = dobError;
    });
    return nameError == null && emailError == null && dobError == null;
  }

  Future<void> _pickDob() async {
    final DateTime now = DateTime.now();
    final DateTime adultDefault = DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dobDate ?? adultDefault,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: RiderColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobDate = picked;
        _dob.text = DateFormat('dd MMM yyyy').format(picked);
        _dobError = null;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final ImageSource? source = await showRiderBottomSheet<ImageSource>(
      context: context,
      title: 'Profile picture',
      actions: const <RiderSheetAction<ImageSource>>[
        RiderSheetAction<ImageSource>(
          label: 'Camera',
          icon: Icons.photo_camera_outlined,
          value: ImageSource.camera,
        ),
        RiderSheetAction<ImageSource>(
          label: 'Gallery',
          icon: Icons.photo_library_outlined,
          value: ImageSource.gallery,
        ),
      ],
    );
    if (source == null || !mounted) return;
    final XFile? photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;
    setState(() => _photoPath = photo.path);
  }

  void _continue() {
    if (!_validate()) return;
    final current = ref.read(riderProfileStateProvider);
    ref.read(riderProfileStateProvider.notifier).state = current.copyWith(
      name: _name.text.trim(),
      mobile: _mobile.text.trim(),
      email: _email.text.trim(),
      dateOfBirth: _dobDate,
      language: _language ?? '',
      photoUrl: _photoPath,
    );
    context.push(RiderRoutes.vehicleType);
  }

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Rider profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: RiderPrimaryButton(
        label: 'Continue',
        onPressed: _continue,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickPhoto,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor:
                        RiderColors.primary.withValues(alpha: 0.15),
                    backgroundImage: _photoPath != null &&
                            _photoPath!.isNotEmpty &&
                            !kIsWeb &&
                            File(_photoPath!).existsSync()
                        ? FileImage(File(_photoPath!))
                        : null,
                    child: _photoPath == null
                        ? const Icon(
                            Icons.add_a_photo_rounded,
                            size: 32,
                            color: RiderColors.primary,
                          )
                        : null,
                  ),
                  const SizedBox(height: RiderSpacing.sm),
                  Text(
                    'Add profile photo',
                    style: RiderTextStyles.caption.copyWith(
                      color: RiderColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                children: [
                  RiderTextField(
                    controller: _name,
                    label: 'Full name',
                    hint: 'Your name',
                    prefixIcon: Icons.badge_outlined,
                    errorText: _nameError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _mobile,
                    label: 'Mobile',
                    prefixIcon: Icons.phone_rounded,
                    enabled: false,
                    readOnly: true,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _email,
                    label: 'Email',
                    hint: 'name@email.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _dob,
                    label: 'Date of birth',
                    prefixIcon: Icons.calendar_month_rounded,
                    readOnly: true,
                    onTap: _pickDob,
                    errorText: _dobError,
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.edit_calendar_rounded,
                        color: RiderColors.primary,
                      ),
                      onPressed: _pickDob,
                    ),
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Preferred language',
                      style: RiderTextStyles.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: RiderSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: _language,
                    hint: Text('Select language', style: RiderTextStyles.hint),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: RiderColors.surface.withValues(alpha: 0.92),
                      prefixIcon: const Icon(
                        Icons.language_rounded,
                        color: RiderColors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: RiderRadius.lgAll,
                        borderSide:
                            const BorderSide(color: RiderColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: RiderRadius.lgAll,
                        borderSide:
                            const BorderSide(color: RiderColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: RiderRadius.lgAll,
                        borderSide: const BorderSide(
                          color: RiderColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: _languages
                        .map(
                          (l) => DropdownMenuItem<String>(
                            value: l,
                            child: Text(l, style: RiderTextStyles.bodyMedium),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _language = v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: RiderSpacing.xl),
          ],
        ),
      ),
    );
  }
}
