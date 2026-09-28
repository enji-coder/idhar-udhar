import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

/// Read-only pickup → drop map. Markers, route, and distance come from the
/// confirmed booking pins and Google Routes. Nothing on this screen edits them.
class RoutePreviewScreen extends ConsumerStatefulWidget {
  const RoutePreviewScreen({super.key});

  @override
  ConsumerState<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends ConsumerState<RoutePreviewScreen> {
  DisplayRoute? _route;
  bool _loading = true;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadRoute());
    });
  }

  List<GeoPoint>? _stops(BookingDraft draft) {
    final List<GeoPoint> points = <GeoPoint>[];
    final MockLocation? pickup = draft.pickup;
    if (pickup?.latitude == null || pickup?.longitude == null) {
      return null;
    }
    points.add(
      GeoPoint(latitude: pickup!.latitude!, longitude: pickup.longitude!),
    );
    for (int i = 0; i < draft.requiredDropCount; i++) {
      final MockLocation? drop = draft.dropAt(i);
      if (drop?.latitude == null || drop?.longitude == null) {
        return null;
      }
      points.add(
        GeoPoint(latitude: drop!.latitude!, longitude: drop.longitude!),
      );
    }
    if (points.length < 2) {
      return null;
    }
    return points;
  }

  Future<void> _loadRoute() async {
    final BookingDraft draft = ref.read(bookingDraftProvider);
    final List<GeoPoint>? stops = _stops(draft);
    if (stops == null) {
      ref.read(bookingDraftProvider.notifier).recordRoute();
      if (mounted) {
        setState(() {
          _route = null;
          _loading = false;
          _unavailable = true;
        });
      }
      return;
    }
    final DisplayRoute? route = await ref.read(routesServiceProvider).compute(
          origin: stops.first,
          destination: stops.last,
          intermediates: stops.length > 2
              ? stops.sublist(1, stops.length - 1)
              : const <GeoPoint>[],
        );
    if (!mounted) {
      return;
    }
    if (route == null || route.points.length < 2) {
      ref.read(bookingDraftProvider.notifier).recordRoute();
      setState(() {
        _route = null;
        _loading = false;
        _unavailable = true;
      });
      return;
    }
    ref.read(bookingDraftProvider.notifier).recordRoute(
          distanceMeters: route.distanceMeters,
          durationSeconds: route.durationSeconds,
        );
    setState(() {
      _route = route;
      _loading = false;
      _unavailable = false;
    });
  }

  List<MapMarkerSpec> _markers(BookingDraft draft) {
    final List<MapMarkerSpec> markers = <MapMarkerSpec>[];
    final MockLocation? pickup = draft.pickup;
    if (pickup?.latitude != null && pickup?.longitude != null) {
      markers.add(
        MapMarkerSpec(
          id: 'pickup',
          point: GeoPoint(
            latitude: pickup!.latitude!,
            longitude: pickup.longitude!,
          ),
          hue: BitmapDescriptor.hueOrange,
          title: 'Pickup',
          snippet: draft.pickupAddressText,
        ),
      );
    }
    for (int i = 0; i < draft.requiredDropCount; i++) {
      final MockLocation? drop = draft.dropAt(i);
      if (drop?.latitude == null || drop?.longitude == null) {
        continue;
      }
      markers.add(
        MapMarkerSpec(
          id: 'drop-$i',
          point: GeoPoint(
            latitude: drop!.latitude!,
            longitude: drop.longitude!,
          ),
          hue: BitmapDescriptor.hueAzure,
          title: draft.requiredDropCount == 1 ? 'Drop' : 'Drop ${i + 1}',
          snippet: draft.locationAddress(drop),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final BookingDraft draft = ref.watch(bookingDraftProvider);
    final List<MapMarkerSpec> markers = _markers(draft);
    final bool canContinue = draft.readyForRoutePreview;
    final GeoPoint? camera = markers.isEmpty ? null : markers.first.point;

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Continue',
        enabled: canContinue,
        onPressed: canContinue
            ? () => context.push(AppRoutes.bookVehicle)
            : null,
      ),
      child: ListView(
        children: [
          Row(
            children: [
              const IuBackButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Route Preview',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Pickup to drop',
            style: AppTextStyles.headingM,
          ),
          const SizedBox(height: AppSpacing.md),
          if (camera != null)
            EmbeddedGoogleMap(
              height: 360,
              initial: camera,
              markers: markers,
              route: _route?.points ?? const <GeoPoint>[],
            )
          else
            const SizedBox.shrink(),
          const SizedBox(height: AppSpacing.sm),
          if (_loading)
            Text(
              'Calculating route…',
              key: const Key('route-preview-calculating'),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else if (_route != null)
            Text(
              _route!.distanceLabel,
              key: const Key('route-preview-distance'),
              style: AppTextStyles.headingS.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            )
          else if (_unavailable)
            Text(
              'Road route is unavailable. Google Routes did not return a path for this trip.',
              key: const Key('route-preview-unavailable'),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.orange,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          if (draft.pickup != null)
            _StopCard(
              title: 'Pickup',
              address: draft.pickupAddressText.isNotEmpty
                  ? draft.pickupAddressText
                  : draft.pickup!.label,
            ),
          for (int i = 0; i < draft.allDrops.length; i++) ...[
            const SizedBox(height: AppSpacing.sm),
            _StopCard(
              title: draft.allDrops.length == 1 ? 'Drop' : 'Drop ${i + 1}',
              address: draft.locationAddress(draft.allDrops[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.title, required this.address});

  final String title;
  final String address;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.orange,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(address, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
