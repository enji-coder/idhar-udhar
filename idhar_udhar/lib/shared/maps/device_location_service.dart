import 'package:permission_handler/permission_handler.dart';

import 'geo_point.dart';
import 'maps_platform.dart';

/// GPS + runtime permission orchestration. Uses existing permission_handler.
class DeviceLocationService {
  DeviceLocationService(this._platform);

  final MapsPlatform _platform;

  Future<bool> isServiceEnabled() => _platform.isLocationServiceEnabled();

  Future<LocationResult> currentLocation({
    bool requestPermission = true,
  }) async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return const LocationResult.fail(
        LocationFailure.permissionPermanentlyDenied,
      );
    }
    if (!(status.isGranted || status.isLimited)) {
      if (!requestPermission) {
        return const LocationResult.fail(LocationFailure.permissionDenied);
      }
      status = await Permission.locationWhenInUse.request();
      if (status.isPermanentlyDenied || status.isRestricted) {
        return const LocationResult.fail(
          LocationFailure.permissionPermanentlyDenied,
        );
      }
      if (!(status.isGranted || status.isLimited)) {
        return const LocationResult.fail(LocationFailure.permissionDenied);
      }
    }

    final bool enabled = await _platform.isLocationServiceEnabled();
    if (!enabled) {
      return const LocationResult.fail(LocationFailure.serviceDisabled);
    }
    return _platform.getCurrentLocation();
  }

  Future<ResolvedAddress?> reverse(GeoPoint point) =>
      _platform.reverseGeocode(point);

  Future<ResolvedAddress?> forward(String query) =>
      _platform.forwardGeocode(query);
}

String locationFailureMessage(LocationFailure failure) {
  switch (failure) {
    case LocationFailure.permissionDenied:
      return 'Location permission is needed to use your current position.';
    case LocationFailure.permissionPermanentlyDenied:
      return 'Location permission is off. Enable it in system settings.';
    case LocationFailure.serviceDisabled:
      return 'Turn on GPS / location services to continue.';
    case LocationFailure.timeout:
      return 'Could not read GPS in time. Try again.';
    case LocationFailure.unavailable:
      return 'Current location is temporarily unavailable.';
  }
}
