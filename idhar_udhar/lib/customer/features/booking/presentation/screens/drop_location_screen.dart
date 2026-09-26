import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/recent_locations_provider.dart';
import '../../../../core/state/saved_addresses_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/custom_snack_bar.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';
import '../widgets/location_source_actions.dart';
import '../widgets/saved_address_picker_sheet.dart';
import 'complete_address_screen.dart';
import 'map_location_picker_screen.dart';

class DropLocationScreen extends ConsumerStatefulWidget {
  const DropLocationScreen({super.key});

  @override
  ConsumerState<DropLocationScreen> createState() => _DropLocationScreenState();
}

class _DropLocationScreenState extends ConsumerState<DropLocationScreen> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _singleFocus = FocusNode();
  final GlobalKey _singleSearchKey = GlobalKey();
  final List<TextEditingController> _dropFields = List<TextEditingController>.generate(
    BookingLimits.maxDeliveryStops,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _dropFocus = List<FocusNode>.generate(
    BookingLimits.maxDeliveryStops,
    (_) => FocusNode(),
  );
  final List<GlobalKey> _dropKeys = List<GlobalKey>.generate(
    BookingLimits.maxDeliveryStops,
    (_) => GlobalKey(),
  );
  final List<String?> _dropErrors =
      List<String?>.filled(BookingLimits.maxDeliveryStops, null);

  /// Active slot for suggestions. Kept after unfocus so a tap on a place
  /// is not lost when the IME dismisses and rebuilds the sliver away.
  int? _activeDropIndex;
  PlacesSearchSession? _places;
  List<PlaceSuggestion> _placeSuggestions = const <PlaceSuggestion>[];
  Timer? _geocodeDebounce;
  bool _resolvingPlace = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _dropFocus.length; i++) {
      _dropFocus[i].addListener(() => _onDropFocusChanged(i));
    }
    _singleFocus.addListener(() {
      if (_singleFocus.hasFocus) {
        _ensureSingleSearchVisible();
      }
    });
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
    _geocodeDebounce?.cancel();
    _search.dispose();
    _singleFocus.dispose();
    for (final TextEditingController controller in _dropFields) {
      controller.dispose();
    }
    for (final FocusNode node in _dropFocus) {
      node.dispose();
    }
    super.dispose();
  }

  void _onDropFocusChanged(int index) {
    if (_dropFocus[index].hasFocus) {
      setState(() => _activeDropIndex = index);
      _ensureDropVisible(index);
    }
  }

  void _ensureDropVisible(int index) {
    void reveal() {
      if (!mounted) {
        return;
      }
      final BuildContext? fieldContext = _dropKeys[index].currentContext;
      if (fieldContext != null && fieldContext.mounted) {
        Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.05,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
    Future<void>.delayed(const Duration(milliseconds: 320), reveal);
  }

  void _ensureSingleSearchVisible() {
    void reveal() {
      if (!mounted) {
        return;
      }
      final BuildContext? fieldContext = _singleSearchKey.currentContext;
      if (fieldContext != null && fieldContext.mounted) {
        Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.05,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
    Future<void>.delayed(const Duration(milliseconds: 320), reveal);
  }

  @override
  Widget build(BuildContext context) {
    final BookingDraft draft = ref.watch(bookingDraftProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncDropFields(ref.read(bookingDraftProvider));
      }
    });

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Continue',
        onPressed: () => _continue(context, draft),
      ),
      child: draft.deliveryMode == DeliveryMode.multiple
          ? _buildMultipleBody(draft)
          : _buildSingleBody(draft),
    );
  }

  Widget _buildHeader(BookingDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const IuBackButton(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Drop Location',
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
                text: 'deliver',
                style: TextStyle(color: AppColors.orange),
              ),
              TextSpan(text: '?'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('How would you like to deliver?', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ModeTile(
                label: 'Single Location',
                selected: draft.deliveryMode == DeliveryMode.single,
                onTap: () => ref
                    .read(bookingDraftProvider.notifier)
                    .setDeliveryMode(DeliveryMode.single),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ModeTile(
                label: 'Multiple Locations',
                selected: draft.deliveryMode == DeliveryMode.multiple,
                onTap: () => ref
                    .read(bookingDraftProvider.notifier)
                    .setDeliveryMode(DeliveryMode.multiple),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleBody(BookingDraft draft) {
    final List<MockLocation> recents = ref.watch(recentLocationsProvider);
    final List<MockLocation> saved =
        ref.watch(savedAddressesProvider).addresses;
    final bool showSuggestions =
        _search.text.trim().length >= 2 && _placeSuggestions.isNotEmpty;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(draft)),
        if (draft.pickup != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _pickupChip(draft),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            key: _singleSearchKey,
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: GlassTextField(
              controller: _search,
              focusNode: _singleFocus,
              hint: 'Search drop location',
              leadingIcon: Icons.search_rounded,
              onTap: _ensureSingleSearchVisible,
              onChanged: _onSingleSearchChanged,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: LocationSourceActions(
            onMap: () => _openMap(),
            onSaved: () => _openSaved(),
          ),
        ),
        if (draft.drop != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: GlassContainer(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  draft.drop!.address.isNotEmpty
                      ? draft.drop!.address
                      : draft.drop!.label,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text('Recent searches', style: AppTextStyles.headingS),
          ),
        ),
        if (showSuggestions)
          SliverList.separated(
            itemCount: _placeSuggestions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _suggestionTile(_placeSuggestions[index]),
          )
        else if (recents.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: GlassContainer(
                child: Text(
                  _search.text.trim().length >= 2
                      ? 'No matching places'
                      : 'No recent searches',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final MockLocation loc = recents[index];
              return _placeTile(
                loc: loc,
                selected: draft.drop?.id == loc.id,
                onTap: () => _finishDrop(loc, null),
                onDelete: () =>
                    ref.read(recentLocationsProvider.notifier).forget(loc.id),
              );
            },
          ),
        if (!showSuggestions)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text('Saved addresses', style: AppTextStyles.headingS),
            ),
          ),
        if (!showSuggestions && saved.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: GlassContainer(
                child: Text(
                  'No saved addresses',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else if (!showSuggestions)
          SliverList.separated(
            itemCount: saved.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final MockLocation loc = saved[index];
              return _placeTile(
                loc: loc,
                selected: draft.drop?.id == loc.id,
                onTap: () => _finishDrop(loc, null),
              );
            },
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: keyboard > 0 ? keyboard : AppSpacing.lg),
        ),
      ],
    );
  }

  Widget _buildMultipleBody(BookingDraft draft) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(draft)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              'How many delivery locations?',
              style: AppTextStyles.caption,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: [
                for (int n = BookingLimits.minMultiDeliveryStops;
                    n <= BookingLimits.maxDeliveryStops;
                    n++) ...[
                  if (n > BookingLimits.minMultiDeliveryStops)
                    const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _CountTile(
                      key: ValueKey<String>('drop-count-$n'),
                      label: '$n',
                      selected: draft.dropCount == n,
                      onTap: () => _onDropCountChanged(n),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (draft.pickup != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _pickupChip(draft),
            ),
          ),
        SliverToBoxAdapter(
          child: LocationSourceActions(
            onMap: () => _openMap(_activeDropIndex ?? 0),
            onSaved: () => _openSaved(_activeDropIndex ?? 0),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < draft.dropCount; i++)
                _dropField(draft, i),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.viewInsetsOf(context).bottom > 0
                ? MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxxl
                : AppSpacing.lg,
          ),
        ),
      ],
    );
  }

  Widget _dropField(BookingDraft draft, int index) {
    final bool active = _activeDropIndex == index;
    final List<MockLocation> places = active
        ? _filteredPlaces(draft, _dropFields[index].text)
        : const <MockLocation>[];
    final bool last = index == draft.dropCount - 1;

    return Padding(
      key: _dropKeys[index],
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Drop Location ${index + 1}',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GlassTextField(
            key: ValueKey<String>('drop-field-$index'),
            controller: _dropFields[index],
            focusNode: _dropFocus[index],
            hint: 'Search drop location ${index + 1}',
            leadingIcon: Icons.flag_rounded,
            errorText: _dropErrors[index],
            textInputAction: last ? TextInputAction.done : TextInputAction.next,
            onTap: () => setState(() => _activeDropIndex = index),
            onChanged: (String value) => _onDropTextChanged(index, value),
            onSubmitted: (_) {
              if (!last) {
                _dropFocus[index + 1].requestFocus();
              }
            },
          ),
          if (active)
            ExcludeFocus(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (places.isEmpty && _placeSuggestions.isEmpty)
                        ? 88
                        : 240,
                  ),
                  child: places.isEmpty && _placeSuggestions.isEmpty
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
                          padding: EdgeInsets.zero,
                          primary: false,
                          shrinkWrap: (places.length + _placeSuggestions.length) <= 3,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: places.length + _placeSuggestions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, placeIndex) {
                            if (placeIndex < places.length) {
                              final MockLocation loc = places[placeIndex];
                              final bool selected =
                                  draft.dropAt(index)?.id == loc.id;
                              return _placeTile(
                                loc: loc,
                                selected: selected,
                                onTap: () => _selectDrop(index, loc),
                              );
                            }
                            return _suggestionTile(
                              _placeSuggestions[placeIndex - places.length],
                              dropIndex: index,
                            );
                          },
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pickupChip(BookingDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppRadius.lgAll,
          child: Row(
            children: [
              const Icon(Icons.trip_origin, color: AppColors.orange),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Pickup: ${draft.pickup!.label}',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        _RouteDistanceLabel(points: _distancePoints(draft)),
      ],
    );
  }

  List<GeoPoint> _distancePoints(BookingDraft draft) {
    final List<GeoPoint> points = <GeoPoint>[];
    final MockLocation? pickup = draft.pickup;
    if (pickup?.latitude == null || pickup?.longitude == null) {
      return points;
    }
    points.add(
      GeoPoint(latitude: pickup!.latitude!, longitude: pickup.longitude!),
    );
    for (int i = 0; i < draft.requiredDropCount; i++) {
      final MockLocation? drop = draft.dropAt(i);
      if (drop?.latitude == null || drop?.longitude == null) {
        break;
      }
      points.add(
        GeoPoint(latitude: drop!.latitude!, longitude: drop.longitude!),
      );
    }
    return points;
  }

  Widget _placeTile({
    required MockLocation loc,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: AppRadius.lgAll,
          borderColor: selected ? AppColors.orange : AppColors.borderGlass,
          child: Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.navy),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.displayLabel, style: AppTextStyles.bodyMedium),
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
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete recent search',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.orange,
                  ),
                )
              else if (selected)
                const Icon(Icons.check_circle, color: AppColors.orange),
            ],
          ),
        ),
      ),
    );
  }

  List<MockLocation> _filteredPlaces(BookingDraft draft, String rawQuery) {
    final String query = rawQuery.trim().toLowerCase();
    final List<MockLocation> saved = ref.read(savedAddressesProvider).addresses;
    final List<MockLocation> recents = ref.read(recentLocationsProvider);
    final List<MockLocation> known = <MockLocation>[
      ...saved,
      ...recents.where((MockLocation loc) => !saved.any((s) => s.id == loc.id)),
    ];
    return known.where((MockLocation loc) {
      if (loc.id == draft.pickup?.id) {
        return false;
      }
      if (query.isEmpty) {
        return false;
      }
      return loc.label.toLowerCase().contains(query) ||
          loc.address.toLowerCase().contains(query) ||
          loc.displayLabel.toLowerCase().contains(query);
    }).toList();
  }

  void _syncDropFields(BookingDraft draft) {
    for (int i = 0; i < BookingLimits.maxDeliveryStops; i++) {
      final MockLocation? loc = draft.dropAt(i);
      final String next = loc == null
          ? ''
          : (loc.address.isNotEmpty ? loc.address : loc.label);
      if (_dropFocus[i].hasFocus) {
        continue;
      }
      if (_dropFields[i].text != next) {
        _dropFields[i].text = next;
      }
    }
  }

  void _onDropCountChanged(int count) {
    ref.read(bookingDraftProvider.notifier).setDropCount(count);
    for (int i = count; i < BookingLimits.maxDeliveryStops; i++) {
      _dropFields[i].clear();
      _dropErrors[i] = null;
      if (_dropFocus[i].hasFocus) {
        _dropFocus[i].unfocus();
      }
    }
    if (_activeDropIndex != null && _activeDropIndex! >= count) {
      _activeDropIndex = null;
    }
    setState(() {});
  }

  void _onSingleSearchChanged(String value) {
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
    _scheduleGeocode(null, value);
  }

  GeoPoint? _bias() {
    final BookingDraft draft = ref.read(bookingDraftProvider);
    final MockLocation? loc = draft.drop ?? draft.pickup;
    if (loc?.latitude != null && loc?.longitude != null) {
      return GeoPoint(latitude: loc!.latitude!, longitude: loc.longitude!);
    }
    return MapsDefaults.cityCenter;
  }

  Widget _suggestionTile(PlaceSuggestion suggestion, {int? dropIndex}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: _resolvingPlace
            ? null
            : () => _selectPlaceSuggestion(suggestion, dropIndex: dropIndex),
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: AppRadius.lgAll,
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppColors.navy),
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

  Future<void> _selectPlaceSuggestion(
    PlaceSuggestion suggestion, {
    int? dropIndex,
  }) async {
    if (_resolvingPlace) {
      return;
    }
    setState(() => _resolvingPlace = true);
    try {
      final ResolvedAddress? details =
          await ref.read(placesServiceProvider).placeDetails(suggestion.placeId);
      if (!mounted || details == null) {
        return;
      }
      final MockLocation loc = MockLocation(
        id: 'place_${suggestion.placeId}',
        label: suggestion.primaryText,
        address: details.address,
        city: details.city,
        iconName: 'place',
        latitude: details.latitude,
        longitude: details.longitude,
      );
      await _finishDrop(loc, dropIndex);
    } finally {
      if (mounted) {
        setState(() => _resolvingPlace = false);
      }
    }
  }

  void _scheduleGeocode(int? index, String query) {
    _geocodeDebounce?.cancel();
    final String trimmed = query.trim();
    if (trimmed.length < 5) {
      return;
    }
    _geocodeDebounce = Timer(const Duration(milliseconds: 550), () async {
      final ResolvedAddress? resolved =
          await ref.read(deviceLocationServiceProvider).forward(trimmed);
      if (!mounted || resolved == null) {
        return;
      }
      final MockLocation loc = MockLocation(
        id: index == null ? 'geocode_drop' : 'geocode_drop_$index',
        label: trimmed,
        address: resolved.address,
        city: resolved.city,
        iconName: 'place',
        latitude: resolved.latitude,
        longitude: resolved.longitude,
      );
      if (index == null) {
        final MockLocation? current = ref.read(bookingDraftProvider).drop;
        if (current != null &&
            current.latitude != null &&
            current.id.startsWith('place_')) {
          return;
        }
        ref.read(bookingDraftProvider.notifier).setDrop(loc);
      } else {
        final MockLocation? current = ref.read(bookingDraftProvider).dropAt(index);
        if (current != null &&
            current.latitude != null &&
            !current.id.startsWith('custom_drop_')) {
          return;
        }
        ref.read(bookingDraftProvider.notifier).setDropAt(index, loc);
      }
    });
  }

  void _onDropTextChanged(int index, String value) {
    if (_dropErrors[index] != null) {
      _dropErrors[index] = null;
    }
    setState(() {});
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      ref.read(bookingDraftProvider.notifier).clearDropAt(index);
      return;
    }
    final List<MockLocation> matches = _filteredPlaces(
      ref.read(bookingDraftProvider),
      trimmed,
    );
    MockLocation? exact;
    for (final MockLocation loc in matches) {
      if (loc.address.toLowerCase() == trimmed.toLowerCase() ||
          loc.label.toLowerCase() == trimmed.toLowerCase() ||
          loc.displayLabel.toLowerCase() == trimmed.toLowerCase()) {
        exact = loc;
        break;
      }
    }
    ref.read(bookingDraftProvider.notifier).setDropAt(
          index,
          exact ??
              MockLocation(
                id: 'custom_drop_$index',
                label: trimmed,
                address: trimmed,
              ),
        );
    _places?.query(
      text: trimmed,
      bias: _bias(),
      onResult: (List<PlaceSuggestion> suggestions) {
        if (!mounted) {
          return;
        }
        setState(() => _placeSuggestions = suggestions);
      },
    );
    if (exact == null || exact.latitude == null) {
      _scheduleGeocode(index, trimmed);
    }
  }

  Future<void> _finishDrop(MockLocation location, int? dropIndex) async {
    final MockLocation? confirmed =
        await CompleteAddressScreen.open(context, initial: location);
    if (!mounted || confirmed == null) {
      return;
    }
    if (dropIndex == null) {
      ref.read(bookingDraftProvider.notifier).setDrop(confirmed);
      _search.text =
          confirmed.address.isNotEmpty ? confirmed.address : confirmed.label;
    } else {
      _selectDrop(dropIndex, confirmed);
    }
    await ref.read(recentLocationsProvider.notifier).remember(confirmed);
    setState(() => _placeSuggestions = const <PlaceSuggestion>[]);
  }

  Future<void> _openMap([int? dropIndex]) async {
    final BookingDraft draft = ref.read(bookingDraftProvider);
    final MockLocation? current =
        dropIndex == null ? draft.drop : draft.dropAt(dropIndex);
    final MockLocation? picked = await MapLocationPickerScreen.open(
      context,
      initial: current,
    );
    if (!mounted || picked == null) {
      return;
    }
    await _finishDrop(picked, dropIndex);
  }

  Future<void> _openSaved([int? dropIndex]) async {
    final MockLocation? picked = await showSavedAddressPicker(context);
    if (!mounted || picked == null) {
      return;
    }
    await _finishDrop(picked, dropIndex);
  }

  void _selectDrop(int index, MockLocation loc) {
    ref.read(bookingDraftProvider.notifier).setDropAt(index, loc);
    _dropFields[index].text = loc.address.isNotEmpty ? loc.address : loc.label;
    _dropErrors[index] = null;
    _dropFocus[index].unfocus();
    setState(() => _activeDropIndex = null);
  }

  void _continue(BuildContext context, BookingDraft draft) {
    final String? message = draft.incompleteStopMessage;
    if (message != null) {
      _showStopErrors(draft);
      CustomSnackBar.error(context, message);
      return;
    }
    context.push(AppRoutes.bookVehicle);
  }

  void _showStopErrors(BookingDraft draft) {
    for (int i = 0; i < _dropErrors.length; i++) {
      _dropErrors[i] = null;
    }
    if (!BookingDraft.isLocationSelected(draft.pickup)) {
      setState(() {});
      return;
    }
    for (int i = 0; i < draft.requiredDropCount; i++) {
      if (draft.dropAt(i) == null) {
        if (draft.deliveryMode == DeliveryMode.multiple) {
          _dropErrors[i] = 'Select Drop Location ${i + 1}';
        }
        setState(() {});
        if (draft.deliveryMode == DeliveryMode.multiple) {
          _dropFocus[i].requestFocus();
          _ensureDropVisible(i);
        }
        return;
      }
    }
    setState(() {});
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderRadius: AppRadius.lgAll,
          borderColor: selected ? AppColors.orange : AppColors.borderGlass,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteDistanceLabel extends ConsumerStatefulWidget {
  const _RouteDistanceLabel({required this.points});

  final List<GeoPoint> points;

  @override
  ConsumerState<_RouteDistanceLabel> createState() =>
      _RouteDistanceLabelState();
}

class _RouteDistanceLabelState extends ConsumerState<_RouteDistanceLabel> {
  String _key = '';
  String? _label;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _RouteDistanceLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(widget.points) != _key) {
      unawaited(_load());
    }
  }

  String _signature(List<GeoPoint> points) {
    return points
        .map(
          (GeoPoint point) =>
              '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}',
        )
        .join('|');
  }

  double? _straightKm(List<GeoPoint> points) {
    if (points.length < 2) {
      return null;
    }
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += GeoMath.haversineKm(
        lat1: points[i - 1].latitude,
        lng1: points[i - 1].longitude,
        lat2: points[i].latitude,
        lng2: points[i].longitude,
      );
    }
    return total;
  }

  Future<void> _load() async {
    final List<GeoPoint> points = widget.points;
    final String key = _signature(points);
    _key = key;
    if (points.length < 2) {
      if (mounted && _label != null) {
        setState(() => _label = null);
      }
      return;
    }
    final DisplayRoute? route = await ref.read(routesServiceProvider).compute(
          origin: points.first,
          destination: points.last,
          intermediates: points.length > 2
              ? points.sublist(1, points.length - 1)
              : const <GeoPoint>[],
        );
    if (!mounted || _key != key) {
      return;
    }
    final double? km = route?.distanceKm ?? _straightKm(points);
    if (km == null) {
      setState(() => _label = null);
      return;
    }
    setState(() => _label = 'Distance: ${km.toStringAsFixed(1)} km');
  }

  @override
  Widget build(BuildContext context) {
    if (_label == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        _label!,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          borderRadius: AppRadius.lgAll,
          borderColor: selected ? AppColors.orange : AppColors.borderGlassStrong,
          backgroundColor: selected
              ? AppColors.orange.withValues(alpha: 0.18)
              : AppColors.glassFillHeavy,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.headingS.copyWith(
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.orange : AppColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}
