import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/business/business.dart';

import '../../../../core/data/mock/mock_data.dart';
import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/saved_addresses_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/custom_snack_bar.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class DropLocationScreen extends ConsumerStatefulWidget {
  const DropLocationScreen({super.key});

  @override
  ConsumerState<DropLocationScreen> createState() => _DropLocationScreenState();
}

class _DropLocationScreenState extends ConsumerState<DropLocationScreen> {
  final TextEditingController _search = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _dropFocus.length; i++) {
      _dropFocus[i].addListener(() => _onDropFocusChanged(i));
    }
  }

  @override
  void dispose() {
    _search.dispose();
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
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) {
        return;
      }
      final BuildContext? fieldContext = _dropKeys[index].currentContext;
      if (fieldContext != null && fieldContext.mounted) {
        Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.12,
        );
      }
    });
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
    final List<MockLocation> places = _filteredPlaces(draft, _search.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(draft),
        const SizedBox(height: AppSpacing.md),
        if (draft.pickup != null) _pickupChip(draft),
        const SizedBox(height: AppSpacing.md),
        GlassTextField(
          controller: _search,
          hint: 'Search drop location',
          leadingIcon: Icons.search_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final MockLocation loc = places[index];
                    final bool selected = draft.drop?.id == loc.id;
                    return _placeTile(
                      loc: loc,
                      selected: selected,
                      onTap: () =>
                          ref.read(bookingDraftProvider.notifier).setDrop(loc),
                    );
                  },
                ),
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
          child: Align(
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
                ? AppSpacing.xxxl
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
                    maxHeight: places.isEmpty ? 88 : 240,
                  ),
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
                          padding: EdgeInsets.zero,
                          primary: false,
                          shrinkWrap: places.length <= 3,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: places.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, placeIndex) {
                            final MockLocation loc = places[placeIndex];
                            final bool selected =
                                draft.dropAt(index)?.id == loc.id;
                            return _placeTile(
                              loc: loc,
                              selected: selected,
                              onTap: () => _selectDrop(index, loc),
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
    return GlassContainer(
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
    );
  }

  Widget _placeTile({
    required MockLocation loc,
    required bool selected,
    required VoidCallback onTap,
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
              if (selected)
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
    final List<MockLocation> catalog = <MockLocation>[
      ...saved,
      ...MockData.locations.where(
        (l) => !saved.any((s) => s.id == l.id),
      ),
    ];
    return catalog.where((MockLocation loc) {
      if (loc.id == draft.pickup?.id) {
        return false;
      }
      if (query.isEmpty) {
        return true;
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
