import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';
import '../../../../core/constants/app_copy.dart';
import '../../../../core/data/mock/mock_data.dart';
import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class VehicleSelectionScreen extends ConsumerWidget {
  const VehicleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(vehicleCategoryCatalogProvider);
    final draft = ref.watch(bookingDraftProvider);
    final List<MockVehicle> options = MockData.vehiclesForFamily(
      draft.serviceFamily,
      catalog: catalog.valueOrNull ?? VehicleCategoryCatalog.active,
    );
    final bool showTwoWheelerNote = options.any(MockData.isTwoWheeler) &&
        (draft.serviceFamily == ServiceFamily.twoWheeler ||
            draft.serviceFamily == null);

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Continue',
        enabled: draft.vehicle != null,
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
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final v = options[index];
                final selected = draft.vehicle?.id == v.id;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppRadius.xlAll,
                    onTap: () =>
                        ref.read(bookingDraftProvider.notifier).setVehicle(v),
                    child: GlassContainer(
                      hero: selected,
                      showAmbientGlow: selected,
                      ambientColor: AppColors.orange,
                      depth: selected
                          ? GlassDepthLevel.hero
                          : GlassDepthLevel.normal,
                      borderColor:
                          selected ? AppColors.orange : AppColors.borderGlass,
                      child: Row(
                        children: [
                          AmbientGlow(
                            diameter: 100,
                            opacity: selected ? 0.28 : 0.12,
                            child: SafeAssetImage(
                              path: v.imagePath,
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
                                Text(v.name, style: AppTextStyles.headingS),
                                Text(
                                  v.description,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${v.capacity} · ${v.etaMinutes} min',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (MockData.isTwoWheeler(v)) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    AppCopy.bikeScootyParcelLimit,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.orange,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                v.fareLabel,
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
            ),
          ),
        ],
      ),
    );
  }
}
