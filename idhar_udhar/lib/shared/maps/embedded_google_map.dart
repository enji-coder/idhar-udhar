import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../customer/core/constants/asset_paths.dart';
import '../../customer/core/theme/theme.dart';
import '../../customer/core/widgets/safe_asset_image.dart';
import 'geo_point.dart';
import 'maps_runtime.dart';
import 'navigation_follow.dart';

class MapMarkerSpec {
  const MapMarkerSpec({
    required this.id,
    required this.point,
    this.hue = BitmapDescriptor.hueOrange,
    this.icon,
    this.title = '',
    this.snippet = '',
    this.rotation = 0,
    this.flat = false,
    this.anchor = const Offset(0.5, 1.0),
    this.zIndex = 0,
  });

  final String id;
  final GeoPoint point;
  final double hue;

  /// When set, used instead of the default hue pin.
  final BitmapDescriptor? icon;
  final String title;
  final String snippet;

  /// Clockwise degrees from the icon's default orientation (north, tip up).
  final double rotation;

  /// When true, [rotation] is relative to the map rather than the screen.
  final bool flat;
  final Offset anchor;
  final int zIndex;
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
    this.fitRouteOnce = false,
    this.deferFitUntilRoute = false,
    this.expanded = false,
    this.navigationMode = false,
    this.navigationBearing = 0,
    this.navigationSpeedMps = 0,
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

  /// Frames pickup and drop immediately, then fits the route once.
  /// Later rebuilds with the same coordinates do not move the camera.
  final bool fitRouteOnce;

  /// Fit the camera once, after a route exists. Marker-only rebuilds do not
  /// move the camera.
  final bool deferFitUntilRoute;

  /// Fill the parent. [height] is ignored.
  final bool expanded;

  /// Rider turn-by-turn presentation: clearer roads, a cased route, and a
  /// camera viewport that stays above the bottom controls.
  final bool navigationMode;

  /// Clockwise degrees from true north. The arrow icon uses the same zero.
  final double navigationBearing;

  /// Ground speed in meters per second. Tilt is applied only while moving.
  final double navigationSpeedMps;

  @override
  State<EmbeddedGoogleMap> createState() => _EmbeddedGoogleMapState();
}

class _EmbeddedGoogleMapState extends State<EmbeddedGoogleMap> {
  GoogleMapController? _controller;
  bool _movingProgrammatically = false;
  String _lastFollowKey = '';
  String _lastFitKey = '';
  final NavigationCameraEpisode _episode = NavigationCameraEpisode();

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

  CameraPosition get _initialCamera {
    if (widget.navigationMode) {
      return CameraPosition(
        target: LatLng(widget.initial.latitude, widget.initial.longitude),
        zoom: NavigationCamera.zoom,
        bearing: widget.navigationBearing,
      );
    }
    final List<GeoPoint> framed = widget.markers
        .map((MapMarkerSpec spec) => spec.point)
        .toList(growable: false);
    if (framed.length < 2) {
      final GeoPoint point = framed.isEmpty ? widget.initial : framed.first;
      return CameraPosition(
        target: LatLng(point.latitude, point.longitude),
        zoom: 15,
      );
    }
    double minLat = framed.first.latitude;
    double maxLat = framed.first.latitude;
    double minLng = framed.first.longitude;
    double maxLng = framed.first.longitude;
    for (final GeoPoint point in framed) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    final double span = math.max(maxLat - minLat, maxLng - minLng);
    final double zoom = span <= 0
        ? 14
        : (math.log(360 / math.max(span, 0.002)) / math.ln2 - 1.4)
            .clamp(11, 15)
            .toDouble();
    return CameraPosition(
      target: LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
      zoom: zoom,
    );
  }

  Set<Marker> get _markers {
    return widget.markers.map((MapMarkerSpec spec) {
      return Marker(
        markerId: MarkerId(spec.id),
        position: LatLng(spec.point.latitude, spec.point.longitude),
        infoWindow: spec.title.isEmpty
            ? InfoWindow.noText
            : InfoWindow(title: spec.title, snippet: spec.snippet),
        icon: spec.icon ?? BitmapDescriptor.defaultMarkerWithHue(spec.hue),
        rotation: spec.rotation,
        flat: spec.flat,
        anchor: spec.anchor,
        zIndexInt: spec.zIndex,
      );
    }).toSet();
  }

  Set<Polyline> get _polylines {
    if (widget.route.length < 2) {
      return const <Polyline>{};
    }
    final List<LatLng> points = widget.route
        .map((GeoPoint p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);
    if (!widget.navigationMode) {
      return <Polyline>{
        Polyline(
          polylineId: const PolylineId('route'),
          color: widget.accentColor,
          width: 4,
          points: points,
        ),
      };
    }
    // Straight segments follow the encoded road geometry. A geodesic chord
    // bows between points and does not match the street.
    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('route-shadow'),
        color: const Color(0x551A3A6E),
        width: 16,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        zIndex: 1,
        points: points,
      ),
      Polyline(
        polylineId: const PolylineId('route-casing'),
        color: const Color(0xFF0D47A1),
        width: 12,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        zIndex: 2,
        points: points,
      ),
      Polyline(
        polylineId: const PolylineId('route-core'),
        color: const Color(0xFF1A73E8),
        width: 7,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        zIndex: 3,
        points: points,
      ),
    };
  }

  Future<void> _syncCamera() async {
    final GoogleMapController? controller = _controller;
    if (controller == null || !mounted) {
      return;
    }
    if (widget.navigationMode && _episode.follow.paused) {
      return;
    }
    if (widget.deferFitUntilRoute && widget.route.length < 2) {
      return;
    }
    if (widget.follow) {
      if (widget.navigationMode) {
        await _syncNavigationCamera(controller);
        return;
      }
      // ~1 m grid. The pose tracker already drops smaller GPS jitter.
      final String key =
          '${widget.initial.latitude.toStringAsFixed(5)},${widget.initial.longitude.toStringAsFixed(5)}';
      if (key != _lastFollowKey) {
        _lastFollowKey = key;
        _movingProgrammatically = true;
        await controller.moveCamera(
          CameraUpdate.newLatLng(
            LatLng(widget.initial.latitude, widget.initial.longitude),
          ),
        );
        _movingProgrammatically = false;
      }
      return;
    }
    if (widget.fitRouteOnce && widget.route.length < 2) {
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
    if (widget.navigationMode) {
      // Follow is off, so this bounds fit can still run. It uses the same
      // single episode as heading-up follow. Fits outside navigation mode
      // are not paired: onCameraMoveStarted is not attached there.
      if (_episode.inFlight || !_episode.requestAppMove()) {
        return;
      }
      _lastFitKey = key;
      _movingProgrammatically = true;
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(_boundsOf(fit), 36),
        );
      } catch (_) {
        if (!_episode.startSeen) {
          _episode.failAppMove();
          _movingProgrammatically = false;
        }
      }
      return;
    }
    _lastFitKey = key;
    _movingProgrammatically = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(_boundsOf(fit), 36),
      );
    } catch (_) {
      // The map view is not ready for a bounds fit yet. The opening camera
      // already frames the stops, and the same coordinates are not fitted again.
    }
    _movingProgrammatically = false;
  }

  Future<void> _syncNavigationCamera(GoogleMapController controller) async {
    if (_episode.follow.paused) {
      return;
    }
    final double tilt = NavigationCamera.tiltForSpeed(widget.navigationSpeedMps);
    final int bucket = NavigationCamera.bearingBucket(widget.navigationBearing);
    final String key =
        '${widget.initial.latitude.toStringAsFixed(5)},${widget.initial.longitude.toStringAsFixed(5)},$bucket,${tilt > 0 ? 1 : 0}';
    if (_episode.inFlight) {
      if (key != _lastFollowKey) {
        _episode.queueLatest();
      }
      return;
    }
    if (key == _lastFollowKey) {
      return;
    }
    if (!_episode.requestAppMove()) {
      return;
    }
    _lastFollowKey = key;
    _movingProgrammatically = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              widget.initial.latitude,
              widget.initial.longitude,
            ),
            zoom: NavigationCamera.zoom,
            tilt: tilt,
            bearing: widget.navigationBearing,
          ),
        ),
      );
    } catch (_) {
      // A thrown future means the call was not accepted. If its start was
      // already delivered, the episode stays open until camera idle.
      if (_episode.startSeen) {
        return;
      }
      _episode.failAppMove();
      _movingProgrammatically = false;
      if (_episode.takeQueue() && mounted) {
        _lastFollowKey = '';
        await _syncNavigationCamera(controller);
      }
    }
  }

  void _handleCameraMoveStarted() {
    if (!widget.navigationMode) {
      return;
    }
    final bool pausedFollow =
        _episode.onMoveStarted(followEnabled: widget.follow);
    if (pausedFollow && mounted) {
      setState(() {});
    }
  }

  Future<void> _handleCameraIdle() async {
    if (widget.navigationMode) {
      final bool applyQueued = _episode.onIdle(followEnabled: widget.follow);
      if (!_episode.inFlight) {
        _movingProgrammatically = false;
      }
      if (applyQueued && mounted) {
        final GoogleMapController? controller = _controller;
        if (controller != null) {
          await _syncNavigationCamera(controller);
        }
      }
    }
    if (widget.onCameraIdle == null || _movingProgrammatically) {
      return;
    }
    final GoogleMapController? controller = _controller;
    if (controller == null) {
      return;
    }
    final LatLngBounds bounds = await controller.getVisibleRegion();
    final GeoPoint center = GeoPoint(
      latitude: (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      longitude: (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );
    widget.onCameraIdle!(center);
  }

  void _resumeFollow() {
    _episode.follow.resume();
    _lastFollowKey = '';
    setState(() {});
    if (_episode.inFlight) {
      _episode.queueLatest();
      return;
    }
    _syncCamera();
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
    final BorderRadius radius =
        widget.navigationMode ? BorderRadius.zero : AppRadius.xlAll;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: widget.navigationMode
            ? null
            : Border.all(color: widget.borderColor),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: widget.expanded ? double.infinity : widget.height,
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
              if (widget.navigationMode && _episode.follow.paused)
                Positioned(
                  right: 12,
                  bottom: 228,
                  child: _MapControlButton(
                    tooltip: 'Resume navigation',
                    icon: Icons.navigation_rounded,
                    onPressed: _resumeFollow,
                  ),
                ),
              if (!widget.navigationMode &&
                  widget.statusMessage != null &&
                  widget.statusMessage!.trim().isNotEmpty)
                Positioned(
                  left: AppSpacing.sm,
                  right: widget.onMyLocation == null ? AppSpacing.sm : 56,
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
      padding: widget.navigationMode
          ? const EdgeInsets.fromLTRB(16, 128, 16, 210)
          : EdgeInsets.zero,
      buildingsEnabled: true,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: widget.navigationMode,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      zoomGesturesEnabled: true,
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
      onCameraMoveStarted:
          widget.navigationMode ? _handleCameraMoveStarted : null,
      onCameraMove: widget.onCameraIdle == null
          ? null
          : (_) {
              // Idle is the commit point for a rider-chosen map center.
            },
      onCameraIdle: widget.navigationMode || widget.onCameraIdle != null
          ? _handleCameraIdle
          : null,
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF1A73E8)),
      ),
    );
  }
}
