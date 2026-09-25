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
    this.showCaption = true,
  });

  final MockLocation? selected;
  final ValueChanged<MockLocation> onSelected;
  final String statusPrefix;
  final double height;
  final bool locateOnStart;
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

  GeoPoint get _cameraTarget {
    final MockLocation? selected = widget.selected;
    if (selected?.latitude != null && selected?.longitude != null) {
      return GeoPoint(
        latitude: selected!.latitude!,
        longitude: selected.longitude!,
      );
    }
    return MapsDefaults.cityCenter;
  }

  @override
  void initState() {
    super.initState();
    _rememberSelected();
    if (widget.locateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _useCurrentLocation(requestPermission: false);
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
      _status = 'Locating…';
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
    widget.onSelected(
      MockLocation(
        id: 'loc_current',
        label: 'Current Location',
        address: resolved?.address ?? 'Current location',
        city: resolved?.city ?? '',
        iconName: 'my_location',
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
    setState(() {
      _locating = false;
      _status = null;
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
    widget.onSelected(
      MockLocation(
        id: 'map_pin',
        label: 'Pinned location',
        address: resolved?.address ?? 'Pinned location',
        city: resolved?.city ?? '',
        iconName: 'place',
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MockLocation? selected = widget.selected;
    final String caption = selected?.address ?? 'Move the map to set a pin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmbeddedGoogleMap(
          height: widget.height,
          initial: _cameraTarget,
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
}
