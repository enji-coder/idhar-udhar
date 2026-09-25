import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../data/models/rider_order.dart';
import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';

class RiderDeliveryMap extends ConsumerStatefulWidget {
  const RiderDeliveryMap({
    required this.order,
    required this.status,
    super.key,
  });

  final RiderOrder order;
  final DeliveryLifecycleStatus status;

  @override
  ConsumerState<RiderDeliveryMap> createState() => _RiderDeliveryMapState();
}

class _RiderDeliveryMapState extends ConsumerState<RiderDeliveryMap> {
  DisplayRoute? _route;
  String? _routeKey;
  DeviceLocation? _here;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateAndRoute();
    });
  }

  @override
  void didUpdateWidget(covariant RiderDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.order.id != widget.order.id) {
      _locateAndRoute();
    }
  }

  GeoPoint? get _pickup {
    if (!widget.order.hasPickupCoords) {
      return null;
    }
    return GeoPoint(
      latitude: widget.order.pickupLatitude!,
      longitude: widget.order.pickupLongitude!,
    );
  }

  GeoPoint? get _drop {
    if (!widget.order.hasDropCoords) {
      return null;
    }
    return GeoPoint(
      latitude: widget.order.dropLatitude!,
      longitude: widget.order.dropLongitude!,
    );
  }

  Future<void> _locateAndRoute() async {
    final LocationResult result = await ref
        .read(deviceLocationServiceProvider)
        .currentLocation(requestPermission: true);
    if (mounted && result.isOk) {
      setState(() {
        _here = result.location;
        _status = null;
      });
    } else if (mounted && result.failure != null) {
      setState(() => _status = locationFailureMessage(result.failure!));
    }
    await _loadRoute();
  }

  Future<void> _loadRoute() async {
    final GeoPoint? pickup = _pickup;
    final GeoPoint? drop = _drop;
    final GeoPoint? here = _here == null
        ? null
        : GeoPoint(latitude: _here!.latitude, longitude: _here!.longitude);
    final bool toDrop = widget.status == DeliveryLifecycleStatus.goingToDrop ||
        widget.status == DeliveryLifecycleStatus.packagePickedUp;
    final GeoPoint? origin = here;
    final GeoPoint? destination = toDrop ? drop : pickup;
    if (origin == null || destination == null) {
      return;
    }
    final String key =
        '${origin.latitude},${origin.longitude}>${destination.latitude},${destination.longitude}';
    if (key == _routeKey) {
      return;
    }
    _routeKey = key;
    final DisplayRoute? route = await ref.read(routesServiceProvider).compute(
          origin: origin,
          destination: destination,
        );
    if (!mounted) {
      return;
    }
    setState(() => _route = route);
  }

  @override
  Widget build(BuildContext context) {
    final GeoPoint? pickup = _pickup;
    final GeoPoint? drop = _drop;
    final GeoPoint? here = _here == null
        ? null
        : GeoPoint(latitude: _here!.latitude, longitude: _here!.longitude);
    final List<MapMarkerSpec> markers = <MapMarkerSpec>[
      if (here != null)
        MapMarkerSpec(
          id: 'rider',
          point: here,
          hue: BitmapDescriptor.hueAzure,
          title: 'You',
        ),
      if (pickup != null)
        MapMarkerSpec(
          id: 'pickup',
          point: pickup,
          hue: BitmapDescriptor.hueOrange,
          title: 'Pickup',
          snippet: widget.order.pickup,
        ),
      if (drop != null)
        MapMarkerSpec(
          id: 'drop',
          point: drop,
          hue: BitmapDescriptor.hueGreen,
          title: 'Drop',
          snippet: widget.order.drop,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmbeddedGoogleMap(
          height: 180,
          initial: here ?? pickup ?? drop ?? MapsDefaults.cityCenter,
          markers: markers,
          route: _route?.points ?? const <GeoPoint>[],
          myLocationEnabled: true,
          accentColor: RiderColors.primary,
          borderColor: RiderColors.border,
          statusMessage: _status,
          onMyLocation: _locateAndRoute,
        ),
        if (_route != null) ...[
          const SizedBox(height: RiderSpacing.sm),
          Text(
            '${_route!.distanceLabel} · ${_route!.etaLabel}',
            style: RiderTextStyles.caption,
          ),
        ],
      ],
    );
  }
}
