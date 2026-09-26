import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class MapLocationPickerScreen extends ConsumerStatefulWidget {
  const MapLocationPickerScreen({super.key, this.initial});

  final MockLocation? initial;

  static Future<MockLocation?> open(
    BuildContext context, {
    MockLocation? initial,
  }) {
    return Navigator.of(context).push<MockLocation>(
      MaterialPageRoute<MockLocation>(
        builder: (_) => MapLocationPickerScreen(initial: initial),
      ),
    );
  }

  @override
  ConsumerState<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState
    extends ConsumerState<MapLocationPickerScreen> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  PlacesSearchSession? _places;
  List<PlaceSuggestion> _suggestions = const <PlaceSuggestion>[];
  bool _resolving = false;
  String? _searchMessage;
  MockLocation? _picked;

  @override
  void initState() {
    super.initState();
    final MockLocation? initial = widget.initial;
    if (initial != null &&
        initial.latitude != null &&
        initial.longitude != null &&
        initial.address.trim().isNotEmpty) {
      _picked = initial;
      _search.text =
          initial.address.isNotEmpty ? initial.address : initial.label;
    }
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
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  GeoPoint? get _bias {
    final MockLocation? picked = _picked;
    if (picked?.latitude == null || picked?.longitude == null) {
      return null;
    }
    return GeoPoint(latitude: picked!.latitude!, longitude: picked.longitude!);
  }

  void _onSearchChanged(String value) {
    final String trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _suggestions = const <PlaceSuggestion>[];
        _searchMessage = null;
      });
      _places?.query(
        text: value,
        bias: _bias,
        onResult: (_) {},
      );
      return;
    }
    setState(() => _searchMessage = null);
    _places?.query(
      text: value,
      bias: _bias,
      onResult: (List<PlaceSuggestion> suggestions) {
        if (!mounted) {
          return;
        }
        setState(() {
          _suggestions = suggestions;
          _searchMessage = suggestions.isEmpty
              ? 'No matching places. Try a street, landmark, or full address.'
              : null;
        });
      },
    );
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    if (_resolving) {
      return;
    }
    setState(() {
      _resolving = true;
      _searchMessage = null;
    });
    try {
      final ResolvedAddress? details = await ref
          .read(placesServiceProvider)
          .placeDetails(suggestion.placeId);
      if (!mounted) {
        return;
      }
      if (details == null) {
        setState(() {
          _searchMessage =
              'That place could not be loaded. Check your connection and try again.';
        });
        return;
      }
      final String address = details.address.trim();
      setState(() {
        _picked = MockLocation(
          id: 'place_${suggestion.placeId}',
          label: suggestion.primaryText,
          address: address,
          city: details.city,
          iconName: 'place',
          latitude: details.latitude,
          longitude: details.longitude,
        );
        _suggestions = const <PlaceSuggestion>[];
        _search.text = address.isNotEmpty ? address : suggestion.primaryText;
      });
      _searchFocus.unfocus();
    } finally {
      if (mounted) {
        setState(() => _resolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canConfirm = _picked != null &&
        _picked!.latitude != null &&
        _picked!.longitude != null &&
        _picked!.address.trim().isNotEmpty;
    final bool showSuggestions = _suggestions.isNotEmpty;

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Confirm',
        enabled: canConfirm && !_resolving,
        onPressed: canConfirm && !_resolving
            ? () => Navigator.of(context).pop(_picked)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IuBackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Select on Map',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GlassTextField(
            controller: _search,
            focusNode: _searchFocus,
            hint: 'Search on map',
            leadingIcon: Icons.search_rounded,
            onChanged: _onSearchChanged,
          ),
          if (_searchMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _searchMessage!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (showSuggestions) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 168,
              child: ListView.separated(
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final PlaceSuggestion suggestion = _suggestions[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AppRadius.lgAll,
                      onTap: () => unawaited(_selectSuggestion(suggestion)),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion.primaryText,
                              style: AppTextStyles.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return BookingLocationMap(
                  selected: _picked,
                  height: constraints.maxHeight,
                  locateOnStart: _picked == null,
                  requestPermissionOnStart: true,
                  showCaption: false,
                  onSelected: (MockLocation loc) {
                    final bool editing = _searchFocus.hasFocus;
                    setState(() {
                      _picked = loc;
                      if (!editing &&
                          loc.address.trim().isNotEmpty &&
                          _search.text.trim() != loc.address.trim()) {
                        _search.text = loc.address;
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
