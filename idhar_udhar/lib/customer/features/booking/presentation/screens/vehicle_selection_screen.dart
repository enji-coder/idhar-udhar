import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';

import '../../../../core/constants/app_copy.dart';
import '../../../../core/data/mock/mock_data.dart';
import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_api.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/state/vehicle_fare.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

VehicleType _typeForVehicle(String vehicle) {
  switch (vehicle) {
    case 'bike':
      return VehicleType.bike;
    case 'scooty':
      return VehicleType.scooty;
    case 'loader_riksha':
      return VehicleType.auto;
    case 'mini_truck':
    case 'tempo':
    case 'large_tempo':
      return VehicleType.pickup;
    case 'truck':
      return VehicleType.truck;
    default:
      return VehicleType.truck;
  }
}

MockVehicle _mockVehicle(VehicleFareOption option) {
  final VehicleType type = _typeForVehicle(option.vehicle);
  final String size = (option.size ?? '').trim();
  return MockVehicle(
    id: option.vehicleCategoryId,
    type: type,
    name: option.name,
    description: size.isEmpty ? 'Available for deliveries' : size,
    capacity: option.capacityLabel,
    etaMinutes: 0,
    baseFare: option.tripFare,
    imagePath: MockData.artworkFor(type),
  );
}

class VehicleSelectionScreen extends ConsumerWidget {
  const VehicleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(vehicleFarePreviewProvider);
    final draft = ref.watch(bookingDraftProvider);
    final bool calculating = preview.isLoading;
    final VehicleFareSelection selection = VehicleFareSelection(
      calculating: calculating,
      options: preview.asData?.value.vehicles ?? const <VehicleFareOption>[],
      selectedId: draft.vehicle?.id,
      family: draft.serviceFamily,
      packageWeightKg: draft.weightKg,
    );
    final List<VehicleFareOption> options = selection.visible;
    final bool showTwoWheelerNote = options.any(
      (VehicleFareOption option) =>
          option.vehicle == 'bike' || option.vehicle == 'scooty',
    );

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Continue',
        enabled: selection.canContinueSelection,
        onPressed: () => context.push(AppRoutes.bookPackage),
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
            calculating
                ? 'Calculating fare for this route...'
                : preview.asData == null
                    ? AppCopy.estimatedPrice
                    : 'Estimated distance ${preview.requireValue.distanceLabel}',
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
          Expanded(child: _body(context, ref, preview, selection, options, draft)),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<VehicleFarePreview> preview,
    VehicleFareSelection selection,
    List<VehicleFareOption> options,
    BookingDraft draft,
  ) {
    if (selection.calculating) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Calculating fare for this route...'),
          ],
        ),
      );
    }
    if (preview.hasError) {
      final Object error = preview.error!;
      final String message = error is ApiException
          ? error.message
          : 'Vehicle fares could not be loaded.';
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => ref.invalidate(vehicleFarePreviewProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (options.isEmpty) {
      return Center(
        child: Text(
          'No vehicles are currently available for this route.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: options.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final VehicleFareOption option = options[index];
        final MockVehicle vehicle = _mockVehicle(option);
        final bool selected = draft.vehicle?.id == option.vehicleCategoryId;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.xlAll,
            onTap: () {
              if (draft.vehicle?.id != option.vehicleCategoryId) {
                ref.read(backendQuoteHoldProvider.notifier).state = null;
              }
              ref.read(bookingDraftProvider.notifier).setVehicle(vehicle);
            },
            child: GlassContainer(
              hero: selected,
              showAmbientGlow: selected,
              ambientColor: AppColors.orange,
              depth: selected ? GlassDepthLevel.hero : GlassDepthLevel.normal,
              borderColor: selected ? AppColors.orange : AppColors.borderGlass,
              child: Row(
                children: [
                  AmbientGlow(
                    diameter: 100,
                    opacity: selected ? 0.28 : 0.12,
                    child: SafeAssetImage(
                      path: vehicle.imagePath,
                      width: 88,
                      height: 72,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.name, style: AppTextStyles.headingS),
                        Text(
                          vehicle.description,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          option.capacityLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        selection.fareLabelFor(option.vehicleCategoryId),
                        style: AppTextStyles.headingS.copyWith(
                          color: AppColors.orange,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
