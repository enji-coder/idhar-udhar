import 'package:flutter/material.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/rider_order.dart';
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

/// Turn-by-turn intent. Google Maps uses the phone's live location as the
/// origin. This URI cannot carry a separate origin.
Uri? googleNavigationUri({
  required double? latitude,
  required double? longitude,
}) {
  if (!_usableCoordinate(latitude, longitude)) {
    return null;
  }
  return Uri.parse('google.navigation:q=$latitude,$longitude&mode=d');
}

/// Google Maps directions to an explicit coordinate. Returns null when the
/// coordinate is missing, non-finite, or outside WGS84 bounds.
///
/// [originLatitude] and [originLongitude] are added only when they are a
/// usable fix and are not the destination. Pickup or drop coordinates are
/// never copied into the origin.
Uri? googleMapsDirectionsUri({
  required double? latitude,
  required double? longitude,
  double? originLatitude,
  double? originLongitude,
}) {
  if (!_usableCoordinate(latitude, longitude)) {
    return null;
  }
  final Map<String, String> parameters = <String, String>{
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'driving',
  };
  if (_usableCoordinate(originLatitude, originLongitude) &&
      !_samePoint(
        originLatitude!,
        originLongitude!,
        latitude!,
        longitude!,
      )) {
    parameters['origin'] = '$originLatitude,$originLongitude';
  }
  return Uri.https('www.google.com', '/maps/dir/', parameters);
}

/// Pickup while riding to the sender. Drop only after the package is picked up
/// or the trip is already going to the drop. No remembered coordinate.
RiderNavTarget? riderNavTargetFor({
  required String orderId,
  required DeliveryLifecycleStatus status,
  required double? pickupLatitude,
  required double? pickupLongitude,
  required double? dropLatitude,
  required double? dropLongitude,
}) {
  final bool toDrop = status == DeliveryLifecycleStatus.packagePickedUp ||
      status == DeliveryLifecycleStatus.goingToDrop;
  final bool toPickup = status == DeliveryLifecycleStatus.accepted ||
      status == DeliveryLifecycleStatus.goingToPickup;
  if (!toDrop && !toPickup) {
    return null;
  }
  final double? latitude = toDrop ? dropLatitude : pickupLatitude;
  final double? longitude = toDrop ? dropLongitude : pickupLongitude;
  if (!_usableCoordinate(latitude, longitude)) {
    return null;
  }
  return RiderNavTarget(
    orderId: orderId,
    toDrop: toDrop,
    latitude: latitude!,
    longitude: longitude!,
  );
}

class RiderNavTarget {
  const RiderNavTarget({
    required this.orderId,
    required this.toDrop,
    required this.latitude,
    required this.longitude,
  });

  final String orderId;
  final bool toDrop;
  final double latitude;
  final double longitude;
}

class RiderNavigationLaunch {
  const RiderNavigationLaunch({
    required this.navigation,
    required this.fallback,
  });

  /// Native turn-by-turn intent. Destination only. Google Maps uses the
  /// phone's live GPS as the origin; this URI cannot carry one.
  final Uri navigation;

  /// HTTPS directions. Includes [origin] only when that fix is usable and is
  /// not the destination.
  final Uri fallback;
}

/// Destination is the order coordinate. [originLatitude] and [originLongitude]
/// are the rider's current GPS fix when one was read. Nothing is hardcoded.
RiderNavigationLaunch? riderNavigationLaunch({
  required double? destinationLatitude,
  required double? destinationLongitude,
  double? originLatitude,
  double? originLongitude,
}) {
  final Uri? navigation = googleNavigationUri(
    latitude: destinationLatitude,
    longitude: destinationLongitude,
  );
  final Uri? fallback = googleMapsDirectionsUri(
    latitude: destinationLatitude,
    longitude: destinationLongitude,
    originLatitude: originLatitude,
    originLongitude: originLongitude,
  );
  if (navigation == null || fallback == null) {
    return null;
  }
  return RiderNavigationLaunch(navigation: navigation, fallback: fallback);
}

/// Short GPS read for the directions fallback. Native navigation still uses
/// the device GPS when this returns null. Flutter tests skip the platform read.
Future<GeoPoint?> readNavigationOrigin(DeviceLocationService service) async {
  if (MapsRuntime.isFlutterTest) {
    return null;
  }
  try {
    final LocationResult result = await service.currentLocation(
      requestPermission: false,
      timeout: const Duration(milliseconds: 1500),
    );
    return result.location?.point;
  } catch (_) {
    return null;
  }
}

/// The overlay ends when the delivery itself ends. Status buttons are not
/// part of the overlay.
bool riderOverlayShouldStop(DeliveryLifecycleStatus status) {
  switch (status) {
    case DeliveryLifecycleStatus.delivered:
    case DeliveryLifecycleStatus.receiverUnavailable:
    case DeliveryLifecycleStatus.parcelAtCompanyOffice:
      return true;
    case DeliveryLifecycleStatus.accepted:
    case DeliveryLifecycleStatus.goingToPickup:
    case DeliveryLifecycleStatus.arrivedAtPickup:
    case DeliveryLifecycleStatus.packagePickedUp:
    case DeliveryLifecycleStatus.goingToDrop:
      return false;
  }
}

/// True for actions that change delivery status. The floating controls must
/// not send these.
bool riderOverlayStatusAction(String action) {
  switch (action) {
    case 'arrived_pickup':
    case 'start_trip':
    case 'arrived_drop':
    case 'receiver_unavailable':
    case 'delivered':
      return true;
    default:
      return false;
  }
}

/// Later phases sort after earlier ones. Terminal outcomes share one rank.
int riderDeliveryPhaseRank(DeliveryLifecycleStatus status) {
  switch (status) {
    case DeliveryLifecycleStatus.accepted:
      return 0;
    case DeliveryLifecycleStatus.goingToPickup:
      return 1;
    case DeliveryLifecycleStatus.arrivedAtPickup:
      return 2;
    case DeliveryLifecycleStatus.packagePickedUp:
      return 3;
    case DeliveryLifecycleStatus.goingToDrop:
      return 4;
    case DeliveryLifecycleStatus.delivered:
    case DeliveryLifecycleStatus.receiverUnavailable:
    case DeliveryLifecycleStatus.parcelAtCompanyOffice:
      return 5;
  }
}

/// Server status to show on return. Null keeps the local phase so a stale
/// read cannot move the rider back to pickup.
DeliveryLifecycleStatus? restoredDeliveryPhase({
  required DeliveryLifecycleStatus local,
  required String? canonicalStatus,
}) {
  final String canonical = (canonicalStatus ?? '').trim();
  if (canonical.isEmpty) {
    return null;
  }
  final DeliveryLifecycleStatus? server =
      OrderMapper.tryRiderLifecycle(canonical);
  if (server == null) {
    return null;
  }
  if (riderDeliveryPhaseRank(server) < riderDeliveryPhaseRank(local)) {
    return null;
  }
  return server;
}

bool riderServerDropArrival(String? canonicalStatus) {
  final String canonical = (canonicalStatus ?? '').trim();
  return canonical == 'NEAR_DROP' || canonical == 'DELIVERY_ATTEMPT';
}

/// Order Details is the screen behind an active trip. Return to the trip
/// after Maps when that handoff is open, or when the phase has already moved
/// past the accepted order.
bool shouldResumeActiveDelivery({
  required bool handoffActive,
  required DeliveryLifecycleStatus status,
  required bool hasOrder,
  required bool onOrderDetails,
}) {
  if (!hasOrder || !onOrderDetails) {
    return false;
  }
  if (handoffActive) {
    return true;
  }
  return status != DeliveryLifecycleStatus.accepted;
}

/// In-memory handoff. Navigation does not write delivery status.
abstract final class RiderNavSession {
  static bool handoffActive = false;
  static bool _restoreOnNext = false;

  static void noteHandoff() {
    handoffActive = true;
  }

  static void requestRestore() {
    _restoreOnNext = true;
  }

  static bool consumeRestore() {
    final bool pending = _restoreOnNext;
    _restoreOnNext = false;
    return pending;
  }

  static void clear() {
    handoffActive = false;
    _restoreOnNext = false;
  }
}

/// Ignores a second tap until [end] runs.
class NavLaunchGate {
  bool _busy = false;

  bool get busy => _busy;

  bool tryBegin() {
    if (_busy) {
      return false;
    }
    _busy = true;
    return true;
  }

  void end() {
    _busy = false;
  }
}

/// The system bubble is visible only while this delivery is armed, the rider
/// app has no started activity, and overlay permission is granted.
/// An activity that has only paused, including while Google Maps is opening,
/// still counts as started and must not show the bubble.
bool riderOverlayWindowVisible({
  required bool deliveryArmed,
  required bool appInBackground,
  required bool anyAppActivityStarted,
  required bool permissionGranted,
  required bool dismissed,
}) {
  return deliveryArmed &&
      appInBackground &&
      !anyAppActivityStarted &&
      permissionGranted &&
      !dismissed;
}

/// The bubble itself returns to the current Rider activity. A drag does not.
/// Options Menu and Close are separate controls and are never fired by a drag.
String? riderBubbleTapAction({required bool dragged}) {
  if (dragged) {
    return null;
  }
  return 'return_to_app';
}

/// Overlay controls other than the bubble. A drag never selects one of them.
String? riderOverlayControlAction({
  required String control,
  required bool dragged,
}) {
  if (dragged) {
    return null;
  }
  switch (control) {
    case 'options_menu':
      return 'options_menu';
    case 'close':
      return 'dismiss';
    case 'bubble':
      return 'return_to_app';
    default:
      return null;
  }
}

Future<bool> launchRiderNavigationTarget({
  required RiderNavTarget target,
  required NavLaunchGate gate,
  required Future<bool> Function(Uri navigation, Uri fallback) launch,
  double? originLatitude,
  double? originLongitude,
}) async {
  if (!gate.tryBegin()) {
    return false;
  }
  try {
    final Uri? navigation = googleNavigationUri(
      latitude: target.latitude,
      longitude: target.longitude,
    );
    final Uri? fallback = googleMapsDirectionsUri(
      latitude: target.latitude,
      longitude: target.longitude,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
    );
    if (navigation == null || fallback == null) {
      return false;
    }
    return await launch(navigation, fallback);
  } finally {
    gate.end();
  }
}

Future<bool> launchMappedNavigation({
  required Uri navigation,
  Uri? fallback,
}) async {
  var opened = false;
  try {
    opened = await externalMapLauncher(navigation);
  } catch (_) {
    opened = false;
  }
  if (!opened && fallback != null) {
    try {
      opened = await externalMapLauncher(fallback);
    } catch (_) {
      opened = false;
    }
  }
  return opened;
}

Future<bool> launchExternalNavigationUris({
  required Uri navigation,
  required Uri? fallback,
  required NavLaunchGate gate,
}) async {
  if (!gate.tryBegin()) {
    return false;
  }
  try {
    return await launchMappedNavigation(
      navigation: navigation,
      fallback: fallback,
    );
  } finally {
    gate.end();
  }
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

bool _samePoint(
  double latitude,
  double longitude,
  double otherLatitude,
  double otherLongitude,
) {
  return (latitude - otherLatitude).abs() < 0.00001 &&
      (longitude - otherLongitude).abs() < 0.00001;
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
