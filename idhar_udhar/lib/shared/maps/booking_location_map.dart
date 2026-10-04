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
  bool _locateRequestInFlight = false;
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
      // Block pin commits until the first GPS attempt finishes.
      _locating = true;
      _status = 'Getting your current location...';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _useCurrentLocation(
            requestPermission: widget.requestPermissionOnStart,
          );
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fillMissingAddress(widget.selected);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant BookingLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rememberSelected();
    final MockLocation? next = widget.selected;
    final MockLocation? prev = oldWidget.selected;
    if (next != null &&
        next.address.trim().isEmpty &&
        (prev == null ||
            prev.latitude != next.latitude ||
            prev.longitude != next.longitude ||
            prev.address.trim().isNotEmpty)) {
      _fillMissingAddress(next);
    }
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

  Future<void> _fillMissingAddress(MockLocation? selected) async {
    if (selected == null ||
        selected.latitude == null ||
        selected.longitude == null ||
        selected.address.trim().isNotEmpty) {
      return;
    }
    final GeoPoint point = GeoPoint(
      latitude: selected.latitude!,
      longitude: selected.longitude!,
    );
    final ResolvedAddress? resolved =
        await ref.read(deviceLocationServiceProvider).reverse(point);
    if (!mounted) {
      return;
    }
    final String address = resolved?.address.trim() ?? '';
    if (address.isEmpty) {
      return;
    }
    widget.onSelected(
      selected.copyWith(
        label: _shortLabel(address),
        address: address,
        city: resolved?.city ?? selected.city,
      ),
    );
  }

  Future<void> _useCurrentLocation({bool requestPermission = true}) async {
    if (_locateRequestInFlight) {
      return;
    }
    _locateRequestInFlight = true;
    setState(() {
      _locating = true;
      _status = 'Getting your current location...';
    });
    try {
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
      _lastGeocoded = point;

      // Apply coordinates immediately so the map/marker can update without
      // waiting on reverse geocoding.
      widget.onSelected(
        MockLocation(
          id: 'loc_current',
          label: 'Current Location',
          address: '',
          city: '',
          iconName: 'my_location',
          latitude: point.latitude,
          longitude: point.longitude,
        ),
      );
      if (mounted) {
        setState(() => _status = 'Getting address...');
      }

      final ResolvedAddress? resolved =
          await ref.read(deviceLocationServiceProvider).reverse(point);
      if (!mounted) {
        return;
      }
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
    } finally {
      _locateRequestInFlight = false;
    }
  }

  void _onCameraIdle(GeoPoint point) {
    if (_locating) {
      return;
    }
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
    // Move selection to the pin immediately; address fills in asynchronously.
    widget.onSelected(
      MockLocation(
        id: 'map_pin',
        label: 'Pinned location',
        address: '',
        city: '',
        iconName: 'place',
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
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
    final GeoPoint camera = _cameraTarget;
    final String caption = (selected?.address.trim().isNotEmpty ?? false)
        ? selected!.address
        : (_status ?? 'Move the map to set a pin');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
}
