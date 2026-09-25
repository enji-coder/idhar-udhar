import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../../../../core/data/mock/mock_data.dart';
import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/recent_locations_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';
import '../widgets/location_source_actions.dart';
import '../widgets/saved_address_picker_sheet.dart';
import 'map_location_picker_screen.dart';

class PickupLocationScreen extends ConsumerStatefulWidget {
  const PickupLocationScreen({super.key});

  @override
  ConsumerState<PickupLocationScreen> createState() =>
      _PickupLocationScreenState();
}

class _PickupLocationScreenState extends ConsumerState<PickupLocationScreen> {
  final TextEditingController _search = TextEditingController();
  PlacesSearchSession? _places;
  List<PlaceSuggestion> _placeSuggestions = const <PlaceSuggestion>[];
  bool _resolvingPlace = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _places = PlacesSearchSession(ref.read(placesServiceProvider));
    });
  }

  @override
  void dispose() {
    _places?.dispose();
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

  GeoPoint? _bias() {
    final MockLocation? pickup = ref.read(bookingDraftProvider).pickup;
    if (pickup?.latitude != null && pickup?.longitude != null) {
      return GeoPoint(
        latitude: pickup!.latitude!,
        longitude: pickup.longitude!,
      );
    }
    return MapsDefaults.cityCenter;
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _places?.query(
      text: value,
      bias: _bias(),
      onResult: (List<PlaceSuggestion> suggestions) {
        if (!mounted) {
          return;
        }
        setState(() => _placeSuggestions = suggestions);
      },
    );
  }

  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    if (_resolvingPlace) {
      return;
    }
    setState(() => _resolvingPlace = true);
    try {
      final ResolvedAddress? details =
          await ref.read(placesServiceProvider).placeDetails(suggestion.placeId);
      if (!mounted) {
        return;
      }
      if (details == null) {
        return;
      }
      ref.read(bookingDraftProvider.notifier).setPickup(
            MockLocation(
              id: 'place_${suggestion.placeId}',
              label: suggestion.primaryText,
              address: details.address,
              city: details.city,
              iconName: 'place',
              latitude: details.latitude,
              longitude: details.longitude,
            ),
          );
      _search.text = suggestion.primaryText;
      setState(() => _placeSuggestions = const <PlaceSuggestion>[]);
      await ref.read(recentLocationsProvider.notifier).remember(
            MockLocation(
              id: 'place_${suggestion.placeId}',
              label: suggestion.primaryText,
              address: details.address,
              city: details.city,
              iconName: 'place',
              latitude: details.latitude,
              longitude: details.longitude,
            ),
          );
    } finally {
      if (mounted) {
        setState(() => _resolvingPlace = false);
      }
    }
  }

  bool _pickupChosen(MockLocation? pickup) {
    if (pickup == null) {
      return false;
    }
    final MockLocation seeded = MockData.locations[4];
    if (pickup.id == seeded.id &&
        pickup.address.trim() == seeded.address.trim()) {
      return false;
    }
    return pickup.address.trim().isNotEmpty || pickup.label.trim().isNotEmpty;
  }

  Future<void> _openMap() async {
    final MockLocation? current = ref.read(bookingDraftProvider).pickup;
    final MockLocation? picked = await MapLocationPickerScreen.open(
      context,
      initial: _pickupChosen(current) ? current : null,
    );
    if (!mounted || picked == null) {
      return;
    }
    ref.read(bookingDraftProvider.notifier).setPickup(picked);
    _search.text = picked.address.isNotEmpty ? picked.address : picked.label;
    await ref.read(recentLocationsProvider.notifier).remember(picked);
  }

  Future<void> _openSaved() async {
    final MockLocation? picked = await showSavedAddressPicker(context);
    if (!mounted || picked == null) {
      return;
    }
    ref.read(bookingDraftProvider.notifier).setPickup(picked);
    _search.text = picked.address.isNotEmpty ? picked.address : picked.label;
    await ref.read(recentLocationsProvider.notifier).remember(picked);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final bool pickupChosen = _pickupChosen(draft.pickup);
    final List<MockLocation> recents = ref.watch(recentLocationsProvider);
    final bool showSuggestions =
        _search.text.trim().length >= 2 && _placeSuggestions.isNotEmpty;

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Continue',
        enabled: pickupChosen,
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
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          LocationSourceActions(onMap: _openMap, onSaved: _openSaved),
          if (pickupChosen) ...[
            const SizedBox(height: AppSpacing.sm),
            GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                draft.pickup!.address.isNotEmpty
                    ? draft.pickup!.address
                    : draft.pickup!.label,
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('Recent', style: AppTextStyles.headingS),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: showSuggestions
                ? ListView.separated(
                    itemCount: _placeSuggestions.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _suggestionTile(_placeSuggestions[index]),
                  )
                : recents.isEmpty
                    ? GlassContainer(
                        child: Text(
                          _search.text.trim().length >= 2
                              ? 'No matching places'
                              : 'No recent searches',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: recents.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final MockLocation loc = recents[index];
                          return _catalogTile(
                            loc,
                            draft.pickup?.id == loc.id,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _catalogTile(MockLocation loc, bool selected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: () => ref.read(bookingDraftProvider.notifier).setPickup(loc),
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: AppRadius.lgAll,
          borderColor: selected ? AppColors.orange : AppColors.borderGlass,
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
                const Icon(Icons.check_circle, color: AppColors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionTile(PlaceSuggestion suggestion) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: _resolvingPlace ? null : () => _selectPlace(suggestion),
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: AppRadius.lgAll,
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppColors.orange),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suggestion.primaryText, style: AppTextStyles.bodyMedium),
                    if (suggestion.subtitle.isNotEmpty)
                      Text(
                        suggestion.subtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
