import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';
import '../widgets/booking_route_preview.dart';

/// Read-only pickup and drop route. It does not change either location.
class PickupToDropPreviewScreen extends ConsumerWidget {
  const PickupToDropPreviewScreen({super.key});

  List<GeoPoint> _points(BookingDraft draft) {
    final List<GeoPoint> points = <GeoPoint>[];
    final MockLocation? pickup = draft.pickup;
    if (pickup?.latitude == null || pickup?.longitude == null) {
      return points;
    }
    points.add(
      GeoPoint(latitude: pickup!.latitude!, longitude: pickup.longitude!),
    );
    for (final MockLocation drop in draft.allDrops) {
      if (drop.latitude == null || drop.longitude == null) {
        break;
      }
      points.add(GeoPoint(latitude: drop.latitude!, longitude: drop.longitude!));
    }
    return points;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BookingDraft draft = ref.watch(bookingDraftProvider);
    final BookingDraftNotifier notifier =
        ref.read(bookingDraftProvider.notifier);
    final List<GeoPoint> points = _points(draft);
    final bool ready = points.length >= 2;
    final double? fare = draft.customerVisibleFare;

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Continue',
        enabled: ready,
        onPressed: ready ? () => context.push(AppRoutes.bookReceiver) : null,
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
                  'Pickup To Drop Preview',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            draft.pickup == null
                ? 'Pickup'
                : 'Pickup: ${draft.locationAddress(draft.pickup!)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.navy),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            draft.drop == null
                ? 'Drop'
                : 'Drop: ${draft.locationAddress(draft.drop!)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.navy),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (fare != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Estimated Fare',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '₹${fare.toStringAsFixed(0)}',
              style: AppTextStyles.headingS.copyWith(color: AppColors.orange),
            ),
          ],
          Expanded(
            child: ready
                ? BookingRoutePreview(
                    points: points,
                    expanded: true,
                    onRoute: (DisplayRoute route) {
                      notifier.applyRouteResult(
                        signature: routePointKey(points),
                        distanceKm: route.distanceKm,
                        durationSeconds: route.durationSeconds,
                      );
                    },
                  )
                : Center(
                    child: Text(
                      'Select a pickup and a drop to preview the route.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
