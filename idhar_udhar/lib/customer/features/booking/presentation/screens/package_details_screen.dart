import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/data/mock/mock_data.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class PackageDetailsScreen extends ConsumerStatefulWidget {
  const PackageDetailsScreen({super.key});

  @override
  ConsumerState<PackageDetailsScreen> createState() =>
      _PackageDetailsScreenState();
}

class _PackageDetailsScreenState extends ConsumerState<PackageDetailsScreen> {
  static const List<double> _presetWeights = <double>[0.5, 1, 2, 5, 10];

  late final TextEditingController _notes;
  late final TextEditingController _customWeight;
  late bool _useCustomWeight;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    _notes = TextEditingController(text: draft.instructions);
    final bool isPreset = _presetWeights.any(
      (w) => (draft.weightKg - w).abs() < 0.001,
    );
    _useCustomWeight = !isPreset;
    _customWeight = TextEditingController(
      text: _useCustomWeight
          ? _formatWeight(draft.weightKg)
          : '',
    );
  }

  @override
  void dispose() {
    _notes.dispose();
    _customWeight.dispose();
    super.dispose();
  }

  String _formatWeight(double kg) {
    return kg == kg.roundToDouble()
        ? kg.toStringAsFixed(0)
        : kg.toStringAsFixed(1);
  }

  String _presetLabel(double kg) => '${_formatWeight(kg)} kg';

  void _selectPreset(double kg) {
    setState(() => _useCustomWeight = false);
    ref.read(bookingDraftProvider.notifier).setWeight(kg);
  }

  void _selectCustom() {
    setState(() => _useCustomWeight = true);
    final parsed = double.tryParse(_customWeight.text.trim());
    if (parsed != null && parsed > 0) {
      ref.read(bookingDraftProvider.notifier).setWeight(parsed);
    }
  }

  void _onCustomWeightChanged(String raw) {
    final String value = raw.trim();
    if (value.isEmpty || value == '.') {
      return;
    }
    final double? parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return;
    }
    ref.read(bookingDraftProvider.notifier).setWeight(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final notifier = ref.read(bookingDraftProvider.notifier);

    return GlassPageScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.lg),
            borderRadius: AppRadius.xlAll,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Price',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹${draft.estimatedFare.toStringAsFixed(0)}',
                        style: AppTextStyles.headingL.copyWith(
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SafeAssetImage(
                  path: AssetPaths.truck,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedPrimaryButton(
            label: 'Continue',
            onPressed: () => context.push(AppRoutes.bookSummary),
          ),
        ],
      ),
      child: ListView(
        children: [
          Row(
            children: [
              const IuBackButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Parcel Details',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('1. Parcel Category', style: AppTextStyles.headingS),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: MockData.parcelCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final c = MockData.parcelCategories[index];
              final selected = draft.categoryId == c.id;
              return InkWell(
                borderRadius: AppRadius.lgAll,
                onTap: () => notifier.setCategory(c.id),
                child: GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  borderRadius: AppRadius.lgAll,
                  borderColor:
                      selected ? AppColors.orange : AppColors.borderGlass,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: SafeAssetImage(
                              path: c.imagePath,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Text(
                            c.label,
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      if (selected)
                        const Positioned(
                          right: 0,
                          top: 0,
                          child: Icon(
                            Icons.check_circle,
                            color: AppColors.orange,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('2. Parcel Size', style: AppTextStyles.headingS),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: MockData.parcelSizes.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final s = MockData.parcelSizes[index];
                final selected = draft.sizeId == s.id;
                return SizedBox(
                  width: 100,
                  child: InkWell(
                    borderRadius: AppRadius.lgAll,
                    onTap: () => notifier.setSize(s.id),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      borderRadius: AppRadius.lgAll,
                      borderColor:
                          selected ? AppColors.orange : AppColors.borderGlass,
                      child: Column(
                        children: [
                          Expanded(
                            child: SafeAssetImage(
                              path: s.imagePath,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Text(s.label,
                              style: AppTextStyles.caption
                                  .copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            s.subtitle,
                            style: AppTextStyles.caption.copyWith(fontSize: 9),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('3. Weight (Actual)', style: AppTextStyles.headingS),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ..._presetWeights.map((kg) {
                final bool selected = !_useCustomWeight &&
                    (draft.weightKg - kg).abs() < 0.001;
                return ChoiceChip(
                  label: Text(_presetLabel(kg)),
                  selected: selected,
                  selectedColor: AppColors.softPeach,
                  onSelected: (_) => _selectPreset(kg),
                );
              }),
              ChoiceChip(
                label: const Text('Custom Weight'),
                selected: _useCustomWeight,
                selectedColor: AppColors.softPeach,
                onSelected: (_) => _selectCustom(),
              ),
            ],
          ),
          if (_useCustomWeight) ...[
            const SizedBox(height: AppSpacing.md),
            GlassTextField(
              controller: _customWeight,
              hint: 'Enter parcel weight',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final String text = newValue.text;
                  if (text.isEmpty) {
                    return newValue;
                  }
                  if (text.startsWith('-')) {
                    return oldValue;
                  }
                  if ('.'.allMatches(text).length > 1) {
                    return oldValue;
                  }
                  return newValue;
                }),
              ],
              trailing: Text(
                'kg',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              onChanged: _onCustomWeightChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.md),
            backgroundColor: AppColors.softPeach.withOpacity(0.55),
            child: Text(
              'Accurate weight helps better price estimation.',
              style: AppTextStyles.caption,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('4. Special instructions', style: AppTextStyles.headingS),
          const SizedBox(height: AppSpacing.md),
          GlassTextField(
            controller: _notes,
            hint: 'Add any special handling instructions...',
            leadingIcon: Icons.chat_bubble_outline_rounded,
            maxLines: 3,
            onChanged: notifier.setInstructions,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_notes.text.length}/120',
              style: AppTextStyles.caption,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: draft.fragile,
                  activeTrackColor: AppColors.orange,
                  title: Text('Fragile item', style: AppTextStyles.bodyMedium),
                  onChanged: notifier.setFragile,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: draft.cod,
                  activeTrackColor: AppColors.orange,
                  title:
                      Text('Cash on delivery', style: AppTextStyles.bodyMedium),
                  onChanged: notifier.setCod,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
