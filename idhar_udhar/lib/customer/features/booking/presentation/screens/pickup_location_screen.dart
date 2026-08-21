import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/data/mock/mock_data.dart';
import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/saved_addresses_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class PickupLocationScreen extends ConsumerStatefulWidget {
  const PickupLocationScreen({super.key});

  @override
  ConsumerState<PickupLocationScreen> createState() =>
      _PickupLocationScreenState();
}

class _PickupLocationScreenState extends ConsumerState<PickupLocationScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  IconData _iconFor(MockLocation loc) {
    switch (loc.iconName) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.work_outline_rounded;
      case 'friend':
        return Icons.people_outline_rounded;
      case 'warehouse':
        return Icons.warehouse_outlined;
      case 'my_location':
        return Icons.my_location_rounded;
      default:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final query = _search.text.trim().toLowerCase();
    final saved = ref.watch(savedAddressesProvider).addresses;
    final catalog = <MockLocation>[
      ...saved,
      ...MockData.locations.where(
        (l) => !saved.any((s) => s.id == l.id),
      ),
    ];
    final places = catalog.where((l) {
      if (query.isEmpty) {
        return true;
      }
      return l.label.toLowerCase().contains(query) ||
          l.address.toLowerCase().contains(query) ||
          l.displayLabel.toLowerCase().contains(query);
    }).toList();

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Continue',
        enabled: draft.pickup != null,
        onPressed: () => context.push(AppRoutes.bookDrop),
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
                  'Pickup Location',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text.rich(
            TextSpan(
              style: AppTextStyles.headingM,
              children: const [
                TextSpan(text: 'Where should we '),
                TextSpan(
                  text: 'pick up',
                  style: TextStyle(color: AppColors.orange),
                ),
                TextSpan(text: '?'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassTextField(
            controller: _search,
            hint: 'Search pickup area',
            leadingIcon: Icons.search_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassContainer(
            hero: true,
            showAmbientGlow: true,
            ambientColor: AppColors.orange,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                AmbientGlow(
                  diameter: 80,
                  opacity: 0.25,
                  child: const SafeAssetImage(
                    path: AssetPaths.locationPin,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Map preview', style: AppTextStyles.bodyMedium),
                      Text(
                        draft.pickup?.address ?? 'Select a pickup point',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Saved & recent', style: AppTextStyles.headingS),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push(AppRoutes.savedAddresses),
              child: Text(
                'Manage saved addresses',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: places.isEmpty
                ? GlassContainer(
                    child: Text(
                      'No matching places',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
              itemCount: places.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final loc = places[index];
                final selected = draft.pickup?.id == loc.id;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppRadius.lgAll,
                    onTap: () =>
                        ref.read(bookingDraftProvider.notifier).setPickup(loc),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      borderRadius: AppRadius.lgAll,
                      borderColor:
                          selected ? AppColors.orange : AppColors.borderGlass,
                      child: Row(
                        children: [
                          Icon(_iconFor(loc), color: AppColors.orange),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loc.label, style: AppTextStyles.bodyMedium),
                                Text(
                                  loc.address,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle,
                                color: AppColors.orange),
                        ],
                      ),
                    ),
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
