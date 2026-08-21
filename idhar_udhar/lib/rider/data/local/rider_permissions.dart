import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../routing/rider_routes.dart';
import 'rider_prefs.dart';

/// Required Rider runtime permissions. Isolated from Customer.
abstract final class RiderPermissions {
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<PermissionStatus> safeStatus(Permission permission) async {
    try {
      if (kIsWeb) return PermissionStatus.granted;
      return await permission.status;
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  static Future<PermissionStatus> safeRequest(Permission permission) async {
    try {
      if (kIsWeb) return PermissionStatus.granted;
      return await permission.request();
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  static bool isUsable(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  /// Location, Camera, Notifications, and Android overlay (order alerts).
  /// No contacts / mic / SMS / storage — file picker does not need it.
  static Future<bool> areAllRequiredGranted() async {
    if (kIsWeb) return true;
    final location = await safeStatus(Permission.locationWhenInUse);
    final camera = await safeStatus(Permission.camera);
    final notification = await safeStatus(Permission.notification);
    if (!isUsable(location) || !isUsable(camera) || !isUsable(notification)) {
      return false;
    }
    if (isAndroid) {
      final overlay = await safeStatus(Permission.systemAlertWindow);
      if (!overlay.isGranted) return false;
    }
    return true;
  }
}

/// Persist dummy login, then Dashboard or permission gate. Never logs out.
Future<void> riderEnterAfterAuth(BuildContext context) async {
  await RiderPrefs.setLoggedIn();
  if (!context.mounted) return;
  await riderGoHomeOrPermissionGate(context);
}

Future<void> riderGoHomeOrPermissionGate(BuildContext context) async {
  final granted = await RiderPermissions.areAllRequiredGranted();
  if (!context.mounted) return;
  if (granted) {
    context.go(RiderRoutes.dashboard);
  } else {
    context.go(RiderRoutes.permissionSetup, extra: 'dashboard');
  }
}
