import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_vehicle_option_card.dart';

class VehicleTypeScreen extends ConsumerStatefulWidget {
  const VehicleTypeScreen({super.key});

  @override
  ConsumerState<VehicleTypeScreen> createState() => _VehicleTypeScreenState();
}

class _VehicleTypeScreenState extends ConsumerState<VehicleTypeScreen> {
  String? _selected;

  String _subtitleFor(String name) {
    switch (name.toLowerCase()) {
      case 'bike':
        return 'Best for city parcels & food';
      case 'auto':
        return 'Ideal for medium packages';
      case 'mini truck':
        return 'For bulk & heavy deliveries';
      default:
        return 'Available for deliveries';
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(vehicleCategoryCatalogProvider);
    final options = catalog.maybeWhen(
      data: (rows) => rows.where((row) => row.isActive).toList(),
      orElse: () => const <VehicleCategory>[],
    );
    final String? selected = _selected ??
        (options.isNotEmpty ? options.first.name : null);

    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Vehicle type'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: RiderPrimaryButton(
        label: 'Continue',
        onPressed: selected == null
            ? null
            : () => context.push(
                  RiderRoutes.vehicleDetails,
                  extra: selected,
                ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Select your vehicle', style: RiderTextStyles.heading),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'Choose the vehicle you will use for deliveries.',
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: RiderSpacing.xl),
            if (catalog.hasError)
              Text(
                'Vehicle categories could not be loaded.',
                style: RiderTextStyles.caption,
              )
            else if (!catalog.isLoading && options.isEmpty)
              Text(
                'No vehicle categories are available.',
                style: RiderTextStyles.caption,
              ),
            for (final category in options) ...[
              RiderVehicleOptionCard(
                label: category.name,
                subtitle: _subtitleFor(category.name),
                recommended: category.name.toLowerCase() == 'bike',
                selected: selected == category.name,
                onTap: () => setState(() => _selected = category.name),
              ),
              const SizedBox(height: RiderSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
