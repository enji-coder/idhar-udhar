import 'package:permission_handler/permission_handler.dart';

import '../routing/app_routes.dart';

/// Thin wrapper around OS location permission for the dummy-data phase.
abstract final class LocationPermissionService {
  static Future<PermissionStatus> status() =>
      Permission.locationWhenInUse.status;

  static Future<bool> isGranted() async {
    final PermissionStatus current = await status();
    return current.isGranted || current.isLimited;
  }

  static Future<PermissionStatus> request() =>
      Permission.locationWhenInUse.request();

  static Future<bool> openSettings() => openAppSettings();

  /// Route after OTP / profile setup — skip location screen if already granted.
  static Future<String> routeAfterAuth({
    required bool needsProfileSetup,
  }) async {
    if (needsProfileSetup) {
      return AppRoutes.profileSetup;
    }
    if (await isGranted()) {
      return AppRoutes.home;
    }
    return AppRoutes.locationPermission;
  }
}
