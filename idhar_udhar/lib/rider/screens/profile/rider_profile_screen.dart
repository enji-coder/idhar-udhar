import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_bike_visual.dart';
import '../../widgets/rider_bottom_sheet.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_section_header.dart';
import '../../widgets/rider_text_field.dart';

class RiderProfileScreen extends ConsumerWidget {
  const RiderProfileScreen({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(riderProfileStateProvider);
    final dob = DateFormat('dd MMM yyyy').format(profile.dateOfBirth);

    final body = SingleChildScrollView(
      padding: showAppBar
          ? EdgeInsets.zero
          : const EdgeInsets.all(RiderSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!showAppBar) ...[
            Text('Profile', style: RiderTextStyles.heading),
            const SizedBox(height: RiderSpacing.xl),
          ],
          RiderGlassCard(
            child: Column(
              children: [
                const _RiderPersonaVisual(),
                const SizedBox(height: RiderSpacing.md),
                Text(
                  profile.name,
                  style: RiderTextStyles.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RiderSpacing.xs),
                RiderStatusChip(
                  label: '${profile.rating.toStringAsFixed(1)} ★',
                  tone: RiderChipTone.success,
                  icon: Icons.star_rounded,
                ),
                const SizedBox(height: RiderSpacing.md),
                TextButton(
                  onPressed: () => _showEditProfileSheet(context, ref),
                  child: Text(
                    'Edit Profile',
                    style: RiderTextStyles.bodyMedium.copyWith(
                      color: RiderColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RiderSpacing.md),
          _SectionCard(
            title: 'Personal details',
            rows: [
              _RowData('Name', profile.name),
              _RowData('Mobile', profile.mobile),
              _RowData('Email', profile.email),
              _RowData('Date of birth', dob),
              _RowData('Language', profile.language),
            ],
          ),
          const SizedBox(height: RiderSpacing.xl),
        ],
      ),
    );

    if (!showAppBar) return body;

    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: body,
    );
  }

  Future<void> _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _EditProfileSheet(),
    );
  }
}

class _RiderPersonaVisual extends StatefulWidget {
  const _RiderPersonaVisual();

  @override
  State<_RiderPersonaVisual> createState() => _RiderPersonaVisualState();
}

class _RiderPersonaVisualState extends State<_RiderPersonaVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idle,
      builder: (context, _) {
        return RiderBikeVisual(
          appear: 1,
          yaw: 0,
          idle: _idle.value,
          height: 148,
        );
      },
    );
  }
}

class _RowData {
  const _RowData(this.label, this.value);
  final String label;
  final String value;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_RowData> rows;

  @override
  Widget build(BuildContext context) {
    return RiderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RiderSectionHeader(title: title),
          const SizedBox(height: RiderSpacing.md),
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(rows[i].label, style: RiderTextStyles.caption),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    rows[i].value,
                    style: RiderTextStyles.bodyMedium,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            if (i < rows.length - 1) const SizedBox(height: RiderSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class RiderProfileAvatar extends StatelessWidget {
  const RiderProfileAvatar({
    required this.photoUrl,
    this.radius = 40,
    super.key,
  });

  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    final path = photoUrl;
    if (path != null && path.isNotEmpty) {
      if (!kIsWeb && File(path).existsSync()) {
        image = FileImage(File(path));
      } else if (path.startsWith('http')) {
        image = NetworkImage(path);
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: RiderColors.primary.withValues(alpha: 0.15),
      backgroundImage: image,
      child: image == null
          ? Icon(
              Icons.person_rounded,
              size: radius + 4,
              color: RiderColors.primary,
            )
          : null,
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _name;
  String? _photoUrl;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(riderProfileStateProvider);
    _name = TextEditingController(text: profile.name);
    _photoUrl = profile.photoUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final source = await showRiderBottomSheet<ImageSource>(
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
    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;
    setState(() => _photoUrl = photo.path);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _nameError = 'Enter your name');
      return;
    }
    final current = ref.read(riderProfileStateProvider);
    ref.read(riderProfileStateProvider.notifier).state = current.copyWith(
      name: name,
      photoUrl: _photoUrl,
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RiderColors.secondary,
        content: Text(
          'Profile updated',
          style: RiderTextStyles.bodyMedium.copyWith(
            color: RiderColors.textOnPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RiderSpacing.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RiderColors.surface,
              borderRadius: RiderRadius.xlAll,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                RiderSpacing.xl,
                RiderSpacing.xl,
                RiderSpacing.xl,
                RiderSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: RiderColors.border,
                          borderRadius: RiderRadius.pillAll,
                        ),
                      ),
                    ),
                    const SizedBox(height: RiderSpacing.lg),
                    Text('Edit Profile', style: RiderTextStyles.title),
                    const SizedBox(height: RiderSpacing.lg),
                    Center(
                      child: Stack(
                        children: [
                          RiderProfileAvatar(photoUrl: _photoUrl, radius: 44),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: RiderColors.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _changePhoto,
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.photo_camera_outlined,
                                    size: 16,
                                    color: RiderColors.textOnPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: RiderSpacing.xl),
                    RiderTextField(
                      controller: _name,
                      label: 'Rider name',
                      hint: 'Enter your name',
                      prefixIcon: Icons.person_outline_rounded,
                      errorText: _nameError,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: RiderSpacing.xl),
                    RiderPrimaryButton(
                      label: 'Save',
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
