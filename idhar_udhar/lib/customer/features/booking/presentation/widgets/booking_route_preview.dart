import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../../../../core/theme/theme.dart';

/// Map preview for the selected pickup and drop. Uses [RoutesService] only.
class BookingRoutePreview extends ConsumerStatefulWidget {
  const BookingRoutePreview({
    required this.points,
    this.loadRoute,
    this.onRoute,
    this.mapHeight = 180,
    this.expanded = false,
    super.key,
  });

  final List<GeoPoint> points;

  /// Test seam. Production uses [routesServiceProvider].
  final Future<DisplayRoute?> Function(List<GeoPoint> points)? loadRoute;

  /// Called once when a route arrives for the current coordinates.
  final ValueChanged<DisplayRoute>? onRoute;

  final double mapHeight;

  /// Fills a parent [Expanded] or [Flexible].
  final bool expanded;

  @override
  ConsumerState<BookingRoutePreview> createState() =>
      _BookingRoutePreviewState();
}

class _BookingRoutePreviewState extends ConsumerState<BookingRoutePreview> {
  String _key = '';
  bool _loading = false;
  DisplayRoute? _route;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _key = _signature(widget.points);
    _loading = widget.points.length >= 2;
    if (_loading) {
      _fetch(_key, List<GeoPoint>.from(widget.points));
    }
  }

  @override
  void didUpdateWidget(covariant BookingRoutePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String key = _signature(widget.points);
    if (key == _key) {
      return;
    }
    _key = key;
    if (widget.points.length < 2) {
      setState(() {
        _route = null;
        _failed = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    _fetch(key, List<GeoPoint>.from(widget.points));
  }

  String _signature(List<GeoPoint> points) => routePointKey(points);

  Future<void> _fetch(String key, List<GeoPoint> points) async {
    DisplayRoute? route;
    var failed = false;
    try {
      final Future<DisplayRoute?> Function(List<GeoPoint> points) load =
          widget.loadRoute ??
          (List<GeoPoint> value) {
            return ref.read(routesServiceProvider).compute(
                  origin: value.first,
                  destination: value.last,
                  intermediates: value.length > 2
                      ? value.sublist(1, value.length - 1)
                      : const <GeoPoint>[],
                );
          };
      route = await load(points);
      failed = route == null;
    } catch (_) {
      failed = true;
      route = null;
    }
    if (_key != key) {
      return;
    }
    if (route != null) {
      widget.onRoute?.call(route);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _route = route;
      _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return const SizedBox.shrink();
    }
    final GeoPoint pickup = widget.points.first;
    final GeoPoint drop = widget.points.last;
    final Widget map = EmbeddedGoogleMap(
      key: const ValueKey<String>('pickup-drop-route-map'),
      height: widget.mapHeight,
      expanded: widget.expanded,
      fitRouteOnce: true,
      deferFitUntilRoute: true,
      initial: pickup,
      markers: <MapMarkerSpec>[
        MapMarkerSpec(
          id: 'pickup',
          point: pickup,
          title: 'Pickup',
        ),
        MapMarkerSpec(
          id: 'drop',
          point: drop,
          hue: BitmapDescriptor.hueAzure,
          title: 'Drop',
        ),
      ],
      route: _route?.points ?? const <GeoPoint>[],
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.expanded) Expanded(child: map) else map,
          const SizedBox(height: AppSpacing.sm),
          if (_loading)
            Text(
              'Calculating route…',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else if (_failed || _route == null)
            Text(
              'Route details are unavailable. Your pickup and drop are still saved.',
              style: AppTextStyles.caption.copyWith(color: AppColors.orange),
            )
          else ...[
            Text(
              'Distance: ${_route!.distanceLabel}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Approx. travel time: ${_route!.etaLabel}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
