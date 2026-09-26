import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customer/core/data/mock/mock_models.dart';
import '../../customer/core/theme/theme.dart';
import 'device_location_service.dart';
import 'embedded_google_map.dart';
import 'geo_point.dart';
import 'maps_providers.dart';

class BookingLocationMap extends ConsumerStatefulWidget {
  const BookingLocationMap({
    required this.selected,
    required this.onSelected,
    super.key,
    this.statusPrefix = 'Map preview',
    this.height = 148,
    this.locateOnStart = false,
    this.requestPermissionOnStart = false,
    this.showCaption = true,
  });

  final MockLocation? selected;
  final ValueChanged<MockLocation> onSelected;
  final String statusPrefix;
  final double height;
  final bool locateOnStart;
  final bool requestPermissionOnStart;
  final bool showCaption;

  @override
  ConsumerState<BookingLocationMap> createState() =>
      _BookingLocationMapState();
}

class _BookingLocationMapState extends ConsumerState<BookingLocationMap> {
  Timer? _geocodeDebounce;
  String? _status;
  bool _locating = false;
  GeoPoint? _lastGeocoded;

  GeoPoint? get _cameraTarget {
    final MockLocation? selected = widget.selected;
    if (selected?.latitude == null || selected?.longitude == null) {
      return null;
    }
    return GeoPoint(
      latitude: selected!.latitude!,
      longitude: selected.longitude!,
    );
  }

  @override
  void initState() {
    super.initState();
    _rememberSelected();
    if (widget.locateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _useCurrentLocation(
            requestPermission: widget.requestPermissionOnStart,
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant BookingLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rememberSelected();
  }

  void _rememberSelected() {
    final MockLocation? selected = widget.selected;
    if (selected?.latitude != null && selected?.longitude != null) {
      _lastGeocoded = GeoPoint(
        latitude: selected!.latitude!,
        longitude: selected.longitude!,
      );
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _useCurrentLocation({bool requestPermission = true}) async {
    if (_locating) {
      return;
    }
    setState(() {
      _locating = true;
      _status = 'Getting your current location...';
    });
    final LocationResult result = await ref
        .read(deviceLocationServiceProvider)
        .currentLocation(requestPermission: requestPermission);
    if (!mounted) {
      return;
    }
    if (!result.isOk) {
      setState(() {
        _locating = false;
        _status = locationFailureMessage(result.failure!);
      });
      return;
    }
    final DeviceLocation location = result.location!;
    final GeoPoint point = location.point;
    final ResolvedAddress? resolved =
        await ref.read(deviceLocationServiceProvider).reverse(point);
    if (!mounted) {
      return;
    }
    _lastGeocoded = point;
    final String address = resolved?.address.trim() ?? '';
    widget.onSelected(
      MockLocation(
        id: 'loc_current',
        label: address.isEmpty ? 'Current Location' : _shortLabel(address),
        address: address,
        city: resolved?.city ?? '',
        iconName: 'my_location',
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
    setState(() {
      _locating = false;
      _status = address.isEmpty
          ? 'Current location found. Address could not be read — move the pin or search.'
          : null;
    });
  }

  void _onCameraIdle(GeoPoint point) {
    final GeoPoint? last = _lastGeocoded;
    if (last != null &&
        (last.latitude - point.latitude).abs() < 0.00012 &&
        (last.longitude - point.longitude).abs() < 0.00012) {
      return;
    }
    final MockLocation? selected = widget.selected;
    if (selected?.latitude != null &&
        selected?.longitude != null &&
        (selected!.latitude! - point.latitude).abs() < 0.00012 &&
        (selected.longitude! - point.longitude).abs() < 0.00012) {
      return;
    }
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 450), () {
      _commitPin(point);
    });
  }

  Future<void> _commitPin(GeoPoint point) async {
    _lastGeocoded = point;
    final ResolvedAddress? resolved =
        await ref.read(deviceLocationServiceProvider).reverse(point);
    if (!mounted) {
      return;
    }
    final String address = resolved?.address.trim() ?? '';
    if (address.isEmpty) {
      setState(() {
        _status =
            'Could not read this address. Move the pin or search again.';
      });
    } else if (_status != null) {
      setState(() => _status = null);
    }
    widget.onSelected(
      MockLocation(
        id: 'map_pin',
        label: address.isEmpty ? 'Pinned location' : _shortLabel(address),
        address: address,
        city: resolved?.city ?? '',
        iconName: 'place',
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
  }

  String _shortLabel(String address) {
    final String part = address.split(',').first.trim();
    return part.isEmpty ? address : part;
  }

  @override
  Widget build(BuildContext context) {
    final MockLocation? selected = widget.selected;
    final GeoPoint? camera = _cameraTarget;
    final String caption = (selected?.address.trim().isNotEmpty ?? false)
        ? selected!.address
        : (_status ?? 'Move the map to set a pin');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (camera == null)
          _awaitingFix(height: widget.height)
        else
          EmbeddedGoogleMap(
            height: widget.height,
            initial: camera,
            follow: true,
            showCenterPin: true,
            myLocationEnabled: true,
            onMyLocation: () => _useCurrentLocation(),
            onCameraIdle: _onCameraIdle,
            statusMessage: _status,
          ),
        if (widget.showCaption) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(widget.statusPrefix, style: AppTextStyles.bodyMedium),
          Text(
            caption,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _awaitingFix({required double height}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: AppColors.borderGlass),
        color: AppColors.navy.withValues(alpha: 0.06),
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_locating) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(
                      _status ??
                          (_locating
                              ? 'Getting your current location...'
                              : 'Search for a place or use your current location.'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Material(
                color: AppColors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  tooltip: 'Use current location',
                  onPressed: _locating ? null : () => _useCurrentLocation(),
                  icon: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
