import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final double mapHeight = MediaQuery.sizeOf(context).height * 0.62;
    final bool canConfirm = _picked != null &&
        _picked!.latitude != null &&
        _picked!.address.trim().isNotEmpty;

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Confirm',
        enabled: canConfirm,
        onPressed: canConfirm ? () => Navigator.of(context).pop(_picked) : null,
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
          BookingLocationMap(
            selected: _picked ?? widget.initial,
            height: mapHeight,
            onSelected: (MockLocation loc) {
              setState(() => _picked = loc);
            },
          ),
        ],
      ),
    );
  }
}
