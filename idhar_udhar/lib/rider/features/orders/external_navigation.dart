import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/rider_colors.dart';
import '../../theme/rider_text_styles.dart';

typedef ExternalMapLauncher = Future<bool> Function(Uri uri);

const String externalNavigationCoordinatesMessage =
    'This location does not have usable coordinates, so navigation was not opened.';

const String externalNavigationFailedMessage =
    'Navigation could not be opened.';

/// Production opener. Tests replace [externalMapLauncher].
ExternalMapLauncher externalMapLauncher = launchExternalMapUrl;

Future<bool> launchExternalMapUrl(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Google Maps directions to an explicit coordinate. Returns null when the
/// coordinate is missing, non-finite, or outside WGS84 bounds.
Uri? googleMapsDirectionsUri({
  required double? latitude,
  required double? longitude,
}) {
  if (!_usableCoordinate(latitude, longitude)) {
    return null;
  }
  return Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'driving',
  });
}

Future<void> openRiderExternalNavigation(
  BuildContext context, {
  required double? latitude,
  required double? longitude,
}) async {
  final Uri? uri = googleMapsDirectionsUri(
    latitude: latitude,
    longitude: longitude,
  );
  if (uri == null) {
    _showNavigationError(context, externalNavigationCoordinatesMessage);
    return;
  }
  var opened = false;
  try {
    opened = await externalMapLauncher(uri);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    _showNavigationError(context, externalNavigationFailedMessage);
  }
}

bool _usableCoordinate(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) {
    return false;
  }
  if (!latitude.isFinite || !longitude.isFinite) {
    return false;
  }
  if (latitude < -90 || latitude > 90) {
    return false;
  }
  if (longitude < -180 || longitude > 180) {
    return false;
  }
  return true;
}

void _showNavigationError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: RiderColors.secondary,
      content: Text(
        message,
        style: RiderTextStyles.bodyMedium.copyWith(
          color: RiderColors.textOnPrimary,
        ),
      ),
    ),
  );
}
