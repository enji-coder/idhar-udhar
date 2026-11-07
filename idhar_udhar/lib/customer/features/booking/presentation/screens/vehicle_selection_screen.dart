import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:idhar_udhar/shared/format/inr_format.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';
import '../../../../core/constants/app_copy.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../core/data/mock/mock_data.dart';
import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_api.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

/// Family from a supported slug pair, or from an exact display name when
/// both slug fields are empty. A name fragment is not a vehicle identity.
ServiceFamily? serviceFamilyForCategory(VehicleCategory category) {
  return MockData.presentationFor(
    vehicleTypeCode: category.vehicleTypeCode,
    vehicleCode: category.vehicleCode,
    name: category.name,
  )?.family;
}

VehicleType? vehicleTypeForCategory(VehicleCategory category) {
  return MockData.presentationFor(
    vehicleTypeCode: category.vehicleTypeCode,
    vehicleCode: category.vehicleCode,
    name: category.name,
  )?.type;
}

/// Display order for Select Vehicle. Catalog codes are the size source:
/// two-wheelers, then three-wheelers, then trucks as mini_truck, tempo,
/// large_tempo, truck. A copy is sorted; [source] is left unchanged.
List<VehicleCategory> sortedVehicleCategoriesForDisplay(
  List<VehicleCategory> source,
) {
  final List<VehicleCategory> copy = List<VehicleCategory>.of(source);
  copy.sort(_compareVehicleCategoryDisplay);
  return copy;
}

int _compareVehicleCategoryDisplay(VehicleCategory a, VehicleCategory b) {
  final int family = _displayFamilyRank(a).compareTo(_displayFamilyRank(b));
  if (family != 0) {
    return family;
  }
  if (_displayFamilyRank(a) != 2) {
    return 0;
  }
  return _truckSizeRank(a).compareTo(_truckSizeRank(b));
}

int _displayFamilyRank(VehicleCategory category) {
  switch ((category.vehicleTypeCode ?? '').trim().toLowerCase()) {
    case 'two_wheeler':
      return 0;
    case 'three_wheeler':
      return 1;
    case 'truck':
      return 2;
  }
  switch (serviceFamilyForCategory(category)) {
    case ServiceFamily.twoWheeler:
      return 0;
    case ServiceFamily.threeWheeler:
      return 1;
    case ServiceFamily.truck:
      return 2;
    case null:
      return 3;
  }
}

/// Matches backend `VEHICLES_FOR_TYPE.truck`: smallest to largest.
int _truckSizeRank(VehicleCategory category) {
  switch ((category.vehicleCode ?? '').trim().toLowerCase()) {
    case 'mini_truck':
      return 0;
    case 'tempo':
      return 1;
    case 'large_tempo':
      return 2;
    case 'truck':
      return 3;
  }
  switch (category.name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim()) {
    case 'mini truck':
      return 0;
    case 'tempo':
      return 1;
    case 'large tempo':
      return 2;
    case 'truck':
      return 3;
    default:
      return 4;
  }
}

List<MockVehicle> vehiclesForBookingFamily(
  List<MockVehicle> vehicles,
  ServiceFamily? family,
) {
  if (family == null) {
    return vehicles;
  }
  return vehicles
      .where((MockVehicle vehicle) => vehicle.serviceFamily == family)
      .toList(growable: false);
}

MockVehicle customerVehicleFromCategory(VehicleCategory category) {
  final VehicleType? type = vehicleTypeForCategory(category);
  return MockVehicle(
    id: category.id,
    type: type ?? VehicleType.car,
    name: category.name,
    description: (category.size ?? '').trim().isEmpty
        ? 'Available for deliveries'
        : category.size!.trim(),
    capacity: (category.weightCapacity ?? '').trim().isEmpty
        ? 'Capacity set by admin'
        : category.weightCapacity!.trim(),
    etaMinutes: 0,
    baseFare: category.baseFare,
    perKm: category.perKm,
    initialMinimum: category.initialMinimum,
    configuredWaiting: category.waiting,
    initialWaitingMinutes: category.initialWaitingMinutes,
    waitingPerMinute: category.waitingPerMinute,
    surge: category.surge,
    toll: category.toll,
    parking: category.parking,
    serviceFamily: serviceFamilyForCategory(category),
    imagePath: type == null
        ? AssetPaths.parcel
        : MockData.artworkFor(type),
  );
}

class VehicleSelectionScreen extends ConsumerWidget {
  const VehicleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(vehicleCategoryCatalogProvider);
    final draft = ref.watch(bookingDraftProvider);
    final AsyncValue<Map<String, String>> farePreview =
        ref.watch(vehicleFarePreviewProvider);
    final List<MockVehicle> options = catalog.maybeWhen(
      data: (List<VehicleCategory> rows) => vehiclesForBookingFamily(
        sortedVehicleCategoriesForDisplay(rows)
            .map(customerVehicleFromCategory)
            .toList(growable: false),
        draft.serviceFamily,
      ),
      orElse: () => const <MockVehicle>[],
    );
    final bool showTwoWheelerNote = options.any(MockData.isTwoWheeler) &&
        (draft.serviceFamily == ServiceFamily.twoWheeler ||
            draft.serviceFamily == null);

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Continue',
        enabled: draft.vehicle != null,
        onPressed: () => context.push(AppRoutes.bookPickup),
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
                  draft.serviceFamily == ServiceFamily.twoWheeler
                      ? 'Select Two Wheeler'
                      : 'Select Vehicle',
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
              children: [
                const TextSpan(text: 'Choose the right '),
                TextSpan(
                  text: draft.serviceFamily == ServiceFamily.twoWheeler
                      ? 'option'
                      : 'ride',
                  style: const TextStyle(color: AppColors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppCopy.estimatedPrice,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (showTwoWheelerNote) ...[
            const SizedBox(height: AppSpacing.md),
            GlassContainer(
              depth: GlassDepthLevel.subtle,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppCopy.bikeScootyParcelLimit,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: catalog.isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: AppSpacing.md),
                        Text('Loading available vehicles...'),
                      ],
                    ),
                  )
                : catalog.hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Vehicle categories could not be loaded.',
                              style: AppTextStyles.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: () => ref.invalidate(
                                vehicleCategoryCatalogProvider,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : options.isEmpty
                        ? Center(
                            child: Text(
                              'No vehicle categories are currently available.',
                              style: AppTextStyles.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: options.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (context, index) {
                              final v = options[index];
                              final selected = draft.vehicle?.id == v.id;
                              final String? serverFare =
                                  farePreview.asData?.value[v.id] ??
                                      farePreview.valueOrNull?[v.id];
                              final String priceLabel;
                              if (serverFare != null && serverFare.isNotEmpty) {
                                priceLabel = formatCustomerPayableText(serverFare);
                              } else if (!draft.hasFareCoordinates &&
                                  !draft.hasInvalidFareCoordinate) {
                                priceLabel =
                                    'Fare calculated after pickup & drop';
                              } else if (farePreview.isLoading) {
                                priceLabel = 'Calculating fare';
                              } else {
                                priceLabel = 'Fare unavailable';
                              }
                              final String waitingNote = v.waitingPerMinute > 0
                                  ? 'Waiting: ₹${v.waitingPerMinute.toStringAsFixed(v.waitingPerMinute == v.waitingPerMinute.roundToDouble() ? 0 : 2)}/min after ${v.initialWaitingMinutes} min'
                                  : '';
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: AppRadius.xlAll,
                                  onTap: () => ref
                                      .read(bookingDraftProvider.notifier)
                                      .setVehicle(v),
                                  child: GlassContainer(
                                    hero: selected,
                                    showAmbientGlow: selected,
                                    ambientColor: AppColors.orange,
                                    depth: selected
                                        ? GlassDepthLevel.hero
                                        : GlassDepthLevel.normal,
                                    borderColor: selected
                                        ? AppColors.orange
                                        : AppColors.borderGlass,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 88,
                                          height: 72,
                                          child: AmbientGlow(
                                            diameter: 88,
                                            opacity: selected ? 0.28 : 0.12,
                                            child: SafeAssetImage(
                                              path: v.imagePath,
                                              width: 88,
                                              height: 72,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                v.name,
                                                style: AppTextStyles.headingS,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                v.description,
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(
                                                  height: AppSpacing.xs),
                                              Text(
                                                v.etaMinutes > 0
                                                    ? '${v.capacity} · ${v.etaMinutes} min'
                                                    : v.capacity,
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                  color: AppColors.navy,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (MockData.isTwoWheeler(v)) ...[
                                                const SizedBox(
                                                    height: AppSpacing.xs),
                                                Text(
                                                  AppCopy.bikeScootyParcelLimit,
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                    color: AppColors.orange,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                priceLabel,
                                                textAlign: TextAlign.end,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                  color: AppColors.orange,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (waitingNote.isNotEmpty)
                                                Text(
                                                  waitingNote,
                                                  textAlign: TextAlign.end,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              if (selected)
                                                const Icon(
                                                  Icons.check_circle,
                                                  color: AppColors.orange,
                                                  size: 22,
                                                ),
                                            ],
                                          ),
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
      ),
    );
  }
}
