import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../customer/core/constants/asset_paths.dart';
import '../../customer/core/theme/theme.dart';
import '../../customer/core/widgets/safe_asset_image.dart';
import 'geo_point.dart';
import 'maps_runtime.dart';

class MapMarkerSpec {
  const MapMarkerSpec({
    required this.id,
    required this.point,
    this.hue = BitmapDescriptor.hueOrange,
    this.title = '',
    this.snippet = '',
  });

  final String id;
  final GeoPoint point;
  final double hue;
  final String title;
  final String snippet;
}

/// Interactive Google Map framed to match existing glass cards (no BackdropFilter).
class EmbeddedGoogleMap extends StatefulWidget {
  const EmbeddedGoogleMap({
    super.key,
    this.height = 148,
    this.initial = MapsDefaults.cityCenter,
    this.markers = const <MapMarkerSpec>[],
    this.route = const <GeoPoint>[],
    this.follow = false,
    this.showCenterPin = false,
    this.myLocationEnabled = false,
    this.accentColor = AppColors.orange,
    this.borderColor = AppColors.borderGlass,
    this.statusMessage,
    this.onCameraIdle,
    this.onMyLocation,
    this.onMapTap,
  });

  final double height;
  final GeoPoint initial;
  final List<MapMarkerSpec> markers;
  final List<GeoPoint> route;
  final bool follow;
  final bool showCenterPin;
  final bool myLocationEnabled;
  final Color accentColor;
  final Color borderColor;
  final String? statusMessage;
  final ValueChanged<GeoPoint>? onCameraIdle;
  final VoidCallback? onMyLocation;
  final ValueChanged<GeoPoint>? onMapTap;

  @override
  State<EmbeddedGoogleMap> createState() => _EmbeddedGoogleMapState();
}

class _EmbeddedGoogleMapState extends State<EmbeddedGoogleMap> {
  GoogleMapController? _controller;
  bool _movingProgrammatically = false;
  String _lastFollowKey = '';
  String _lastFitKey = '';

  @override
  void didUpdateWidget(covariant EmbeddedGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  CameraPosition get _initialCamera => CameraPosition(
        target: LatLng(widget.initial.latitude, widget.initial.longitude),
        zoom: 15.2,
      );

  Set<Marker> get _markers {
    return widget.markers.map((MapMarkerSpec spec) {
      return Marker(
        markerId: MarkerId(spec.id),
        position: LatLng(spec.point.latitude, spec.point.longitude),
        infoWindow: spec.title.isEmpty
            ? InfoWindow.noText
            : InfoWindow(title: spec.title, snippet: spec.snippet),
        icon: BitmapDescriptor.defaultMarkerWithHue(spec.hue),
      );
    }).toSet();
  }

  Set<Polyline> get _polylines {
    if (widget.route.length < 2) {
      return const <Polyline>{};
    }
    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        color: widget.accentColor,
        width: 4,
        points: widget.route
            .map((GeoPoint p) => LatLng(p.latitude, p.longitude))
            .toList(growable: false),
      ),
    };
  }

  Future<void> _syncCamera() async {
    final GoogleMapController? controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    if (widget.follow) {
      final String key =
          '${widget.initial.latitude.toStringAsFixed(5)},${widget.initial.longitude.toStringAsFixed(5)}';
      if (key != _lastFollowKey) {
        _lastFollowKey = key;
        _movingProgrammatically = true;
        await controller.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(widget.initial.latitude, widget.initial.longitude),
          ),
        );
        _movingProgrammatically = false;
      }
      return;
    }
    final List<LatLng> fit = <LatLng>[
      ...widget.markers.map(
        (MapMarkerSpec spec) =>
            LatLng(spec.point.latitude, spec.point.longitude),
      ),
      ...widget.route.map(
        (GeoPoint point) => LatLng(point.latitude, point.longitude),
      ),
    ];
    if (fit.length < 2) {
      return;
    }
    final String key = fit
        .map(
          (LatLng p) =>
              '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}',
        )
        .join('|');
    if (key == _lastFitKey) {
      return;
    }
    _lastFitKey = key;
    _movingProgrammatically = true;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsOf(fit), 36),
    );
    _movingProgrammatically = false;
  }

  LatLngBounds _boundsOf(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final LatLng point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    if ((maxLat - minLat).abs() < 0.002) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if ((maxLng - minLng).abs() < 0.002) {
      minLng -= 0.002;
      maxLng += 0.002;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = AppRadius.xlAll;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: widget.borderColor),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(child: _mapOrPlaceholder()),
              if (widget.showCenterPin)
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 28),
                      child: SafeAssetImage(
                        path: AssetPaths.locationPin,
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              if (widget.onMyLocation != null)
                Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: Material(
                    color: AppColors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      tooltip: 'Use current location',
                      onPressed: widget.onMyLocation,
                      icon: Icon(
                        Icons.my_location_rounded,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ),
              if (widget.statusMessage != null &&
                  widget.statusMessage!.trim().isNotEmpty)
                Positioned(
                  left: AppSpacing.sm,
                  right: widget.onMyLocation == null
                      ? AppSpacing.sm
                      : 56,
                  top: AppSpacing.sm,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.92),
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        widget.statusMessage!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapOrPlaceholder() {
    if (!MapsRuntime.useGoogleMapWidget) {
      return ColoredBox(
        color: AppColors.navy.withValues(alpha: 0.06),
        child: Center(
          child: Icon(Icons.map_outlined, color: widget.accentColor, size: 36),
        ),
      );
    }
    return GoogleMap(
      initialCameraPosition: _initialCamera,
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      liteModeEnabled: false,
      onMapCreated: (GoogleMapController controller) {
        _controller = controller;
        _syncCamera();
      },
      onTap: widget.onMapTap == null
          ? null
          : (LatLng value) => widget.onMapTap!(
                GeoPoint(latitude: value.latitude, longitude: value.longitude),
              ),
      onCameraMove: widget.onCameraIdle == null
          ? null
          : (_) {
              // Keep listener registered; idle is the commit point.
            },
      onCameraIdle: widget.onCameraIdle == null
          ? null
          : () async {
              if (_movingProgrammatically) {
                return;
              }
              final GoogleMapController? controller = _controller;
              if (controller == null) {
                return;
              }
              final LatLngBounds bounds = await controller.getVisibleRegion();
              final GeoPoint center = GeoPoint(
                latitude: (bounds.northeast.latitude +
                        bounds.southwest.latitude) /
                    2,
                longitude: (bounds.northeast.longitude +
                        bounds.southwest.longitude) /
                    2,
              );
              widget.onCameraIdle!(center);
            },
    );
  }
}
