import 'dart:async';

import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

/// Publishes rider GPS to the existing POST /v1/rider/location contract.
class RiderLocationPublisher {
  RiderLocationPublisher({
    required DeviceLocationService location,
    required RiderApi api,
  })  : _location = location,
        _api = api;

  final DeviceLocationService _location;
  final RiderApi _api;
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    final LocationResult result =
        await _location.currentLocation(requestPermission: false);
    if (!result.isOk) {
      return;
    }
    try {
      await _api.postLocation(
        latitude: result.location!.latitude,
        longitude: result.location!.longitude,
      );
    } on ApiException {
      // Existing backend may be offline; do not interrupt delivery UI.
    }
  }
}
