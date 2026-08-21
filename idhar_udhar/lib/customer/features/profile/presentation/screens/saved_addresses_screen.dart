import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/state/saved_addresses_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

/// Manage saved addresses — uses existing glass components (no redesign).
class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  IconData _iconFor(MockLocation loc) {
    switch (loc.iconName) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.work_outline_rounded;
      case 'friend':
        return Icons.people_outline_rounded;
      default:
        return Icons.place_outlined;
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    MockLocation? existing,
  }) async {
    final MockLocation? result = await showModalBottomSheet<MockLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddressEditorSheet(existing: existing),
    );
    if (result == null) {
      return;
    }
    if (existing == null) {
      await ref.read(savedAddressesProvider.notifier).add(result);
    } else {
      await ref.read(savedAddressesProvider.notifier).update(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SavedAddressesState state = ref.watch(savedAddressesProvider);

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Add Address',
        onPressed: () => _openEditor(context, ref),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IuBackButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Saved Addresses',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (state.isLoading)
            const Expanded(child: Center(child: LoadingIndicator(width: 140)))
          else if (state.error != null)
            Expanded(
              child: GlassContainer(
                child: EmptyState(
                  title: 'Could not load addresses',
                  subtitle: state.error ?? 'Please try again.',
                  action: AnimatedPrimaryButton(
                    label: 'Retry',
                    onPressed: () =>
                        ref.read(savedAddressesProvider.notifier).load(),
                  ),
                ),
              ),
            )
          else if (state.isEmpty)
            Expanded(
              child: GlassContainer(
                child: EmptyState(
                  title: 'No saved addresses',
                  subtitle: 'Add Home, Office, Friend or Other for faster booking.',
                  action: AnimatedPrimaryButton(
                    label: 'Add Address',
                    onPressed: () => _openEditor(context, ref),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: state.addresses.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final MockLocation loc = state.addresses[index];
                  return GlassContainer(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Icon(_iconFor(loc), color: AppColors.orange),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.displayLabel,
                                style: AppTextStyles.bodyMedium,
                              ),
                              Text(
                                loc.address,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (loc.landmark.trim().isNotEmpty)
                                Text(
                                  'Landmark: ${loc.landmark}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () =>
                              _openEditor(context, ref, existing: loc),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.navy,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => ref
                              .read(savedAddressesProvider.notifier)
                              .delete(loc.id),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AddressEditorSheet extends StatefulWidget {
  const _AddressEditorSheet({this.existing});

  final MockLocation? existing;

  @override
  State<_AddressEditorSheet> createState() => _AddressEditorSheetState();
}

class _AddressEditorSheetState extends State<_AddressEditorSheet> {
  late AddressLabel _label;
  late final TextEditingController _address;
  late final TextEditingController _landmark;
  late final TextEditingController _city;
  String? _error;

  @override
  void initState() {
    super.initState();
    final MockLocation? existing = widget.existing;
    _label = existing?.addressLabel ??
        AddressLabel.fromTitle(existing?.label ?? 'Home');
    _address = TextEditingController(text: existing?.address ?? '');
    _landmark = TextEditingController(text: existing?.landmark ?? '');
    _city = TextEditingController(text: existing?.city ?? 'Ahmedabad');
  }

  @override
  void dispose() {
    _address.dispose();
    _landmark.dispose();
    _city.dispose();
    super.dispose();
  }

  void _save() {
    final String address = _address.text.trim();
    if (address.length < 5) {
      setState(() => _error = 'Enter a valid address');
      return;
    }
    final DateTime now = DateTime.now();
    final MockLocation? existing = widget.existing;
    Navigator.of(context).pop(
      MockLocation(
        id: existing?.id ?? 'loc_${now.millisecondsSinceEpoch}',
        label: _label.title,
        address: address,
        city: _city.text.trim(),
        landmark: _landmark.text.trim(),
        isSaved: true,
        iconName: _label.iconName,
        addressLabel: _label,
        latitude: existing?.latitude,
        longitude: existing?.longitude,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.existing == null ? 'Add Address' : 'Edit Address',
                style: AppTextStyles.headingS,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: AddressLabel.values.map((label) {
                  final bool selected = _label == label;
                  return ChoiceChip(
                    label: Text(label.title),
                    selected: selected,
                    selectedColor: AppColors.softPeach,
                    onSelected: (_) => setState(() => _label = label),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              GlassTextField(
                controller: _address,
                hint: 'Full address',
                leadingIcon: Icons.place_outlined,
                transparentBackground: true,
                errorText: _error,
                onChanged: (_) {
                  if (_error != null) {
                    setState(() => _error = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              GlassTextField(
                controller: _landmark,
                hint: 'Landmark (optional)',
                leadingIcon: Icons.flag_outlined,
                transparentBackground: true,
              ),
              const SizedBox(height: AppSpacing.md),
              GlassTextField(
                controller: _city,
                hint: 'City',
                leadingIcon: Icons.location_city_outlined,
                transparentBackground: true,
              ),
              const SizedBox(height: AppSpacing.xl),
              AnimatedPrimaryButton(label: 'Save Address', onPressed: _save),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
