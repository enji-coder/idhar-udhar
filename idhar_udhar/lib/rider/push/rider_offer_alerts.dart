import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:idhar_udhar/shared/format/trip_distance.dart';

import '../data/models/rider_order.dart';
import 'rider_offer_diag.dart';
import 'rider_offer_rules.dart';

export 'rider_offer_rules.dart';

const String riderOfferChannelId = 'rider_incoming_offers_v1';

enum RiderOfferAlertOutcome {
  posted,
  skipped,
  permissionDenied,
  failed,
}

/// Offer ids already alerted in this process. Stops duplicate sounds.
final Set<String> _alertedOfferIds = <String>{};

/// Set when a notification opens the app. The offer screen reads the id once.
String? riderOfferLaunchAction;

String? riderOfferLaunchOfferId;

final RiderOfferActionGate riderOfferActionGate = RiderOfferActionGate();

final StreamController<RiderOfferUserAction> _offerActionController =
    StreamController<RiderOfferUserAction>.broadcast();

/// Accept/Reject taps. The pending action remains until the offer screen consumes it.
Stream<RiderOfferUserAction> get riderOfferUserActions => _offerActionController.stream;

/// Tap/open, Accept, or Reject on the local notification — listener opens the offer UI.
class RiderOfferPresentRequest {
  const RiderOfferPresentRequest({
    required this.offerId,
    required this.action,
  });

  final String offerId;
  final String action;
}

final StreamController<RiderOfferPresentRequest> _presentController =
    StreamController<RiderOfferPresentRequest>.broadcast();

Stream<RiderOfferPresentRequest> get riderOfferPresentRequests =>
    _presentController.stream;

void deliverRiderOfferNotification({String? offerId, String? action}) {
  final String id = (offerId ?? '').trim();
  final String act = (action ?? 'open').trim();
  if (id.isNotEmpty) {
    riderOfferLaunchOfferId = id;
    riderOfferLaunchAction = act;
    riderOfferLog('notification_action', offerId: id, reason: act);
    if (!_presentController.isClosed) {
      _presentController.add(RiderOfferPresentRequest(offerId: id, action: act));
    }
  }
  final RiderOfferUserAction? delivered = riderOfferActionGate.note(id, act);
  if (delivered != null && !_offerActionController.isClosed) {
    _offerActionController.add(delivered);
  }
}

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

const MethodChannel _offerChannel = MethodChannel('com.idharudhar.rider/offer_alerts');

bool _ready = false;

@pragma('vm:entry-point')
Future<void> riderFirebaseBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] != 'OFFER_NEW') {
    return;
  }
  riderOfferLog(
    'fcm_background_received',
    offerId: message.data['offer_id']?.toString(),
    reason: 'background',
  );
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  await showRiderOfferAlert(
    _stringData(message.data),
    postSystemNotification: true,
  );
}

@pragma('vm:entry-point')
void riderOfferNotificationTap(NotificationResponse response) {
  deliverRiderOfferNotification(
    offerId: response.payload,
    action: response.actionId ?? 'open',
  );
}

Future<void> ensureRiderOfferAlerts() async {
  if (_ready) {
    return;
  }
  const AndroidInitializationSettings android =
      AndroidInitializationSettings('@mipmap/ic_launcher_rider');
  await _plugin.initialize(
    const InitializationSettings(android: android),
    onDidReceiveNotificationResponse: riderOfferNotificationTap,
    onDidReceiveBackgroundNotificationResponse: riderOfferNotificationTap,
  );
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      riderOfferChannelId,
      'Incoming delivery requests',
      description: 'Alerts when a new delivery is offered to you.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
    ),
  );
  _ready = true;
  riderOfferLog('local_notifications_ready');
}

Future<bool> riderFullScreenOffersAllowed() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }
  try {
    final bool? allowed =
        await _offerChannel.invokeMethod<bool>('canUseFullScreenIntent');
    return allowed ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> openRiderFullScreenOfferSettings() async {
  await ensureRiderOfferAlerts();
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.requestFullScreenIntentPermission();
}

Future<RiderOfferAlertOutcome> showRiderOfferAlert(
  Map<String, String> data, {
  bool postSystemNotification = true,
  bool requestPermissionIfNeeded = false,
}) async {
  final String offerId = (data['offer_id'] ?? '').trim();
  if (offerId.isEmpty) {
    riderOfferLog('alert_skipped', reason: 'missing_offer_id');
    return RiderOfferAlertOutcome.skipped;
  }
  if (_alertedOfferIds.contains(offerId)) {
    riderOfferLog('alert_skipped', offerId: offerId, reason: 'duplicate_alert');
    return RiderOfferAlertOutcome.skipped;
  }
  final DateTime? expiresAt = DateTime.tryParse((data['expires_at'] ?? '').trim());
  final OfferNotificationWindow window =
      offerNotificationWindow(expiresAt, DateTime.now());
  if (window.expired) {
    riderOfferLog('alert_skipped', offerId: offerId, reason: 'already_expired');
    return RiderOfferAlertOutcome.skipped;
  }
  if (!postSystemNotification) {
    riderOfferLog('alert_in_app_only', offerId: offerId);
    return RiderOfferAlertOutcome.skipped;
  }
  await ensureRiderOfferAlerts();
  final bool? allowed = await _notificationsAllowed(
    requestIfNeeded: requestPermissionIfNeeded,
  );
  if (allowed != true) {
    riderOfferLog(
      'alert_skipped',
      offerId: offerId,
      reason: allowed == false
          ? 'notification_permission_denied'
          : 'notification_permission_unknown',
    );
    return allowed == false
        ? RiderOfferAlertOutcome.permissionDenied
        : RiderOfferAlertOutcome.failed;
  }
  final bool fsiAllowed = await riderFullScreenOffersAllowed();
  riderOfferLog(
    'local_notification_posting',
    offerId: offerId,
    reason: fsiAllowed ? 'full_screen_intent_allowed' : 'full_screen_intent_denied_heads_up',
  );
  final String title = (data['title'] ?? '').trim().isEmpty
      ? 'New delivery request'
      : data['title']!.trim();
  _alertedOfferIds.add(offerId);
  try {
    await _plugin.show(
    _notificationId(offerId),
    title,
    _alertBody(data),
    NotificationDetails(
      android: AndroidNotificationDetails(
        riderOfferChannelId,
        'Incoming delivery requests',
        channelDescription: 'Alerts when a new delivery is offered to you.',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.navigation,
        visibility: NotificationVisibility.public,
        // The OS shows the activity only when full-screen access is allowed.
        // Otherwise this stays a high-importance heads-up notification.
        fullScreenIntent: true,
        timeoutAfter: window.timeoutAfterMs,
        playSound: true,
        enableVibration: true,
        ticker: 'New delivery request',
        styleInformation: BigTextStyleInformation(_alertBody(data)),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'reject',
            'Reject',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'accept',
            'Accept',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    ),
    payload: offerId,
    );
  } catch (error) {
    _alertedOfferIds.remove(offerId);
    riderOfferLog(
      'local_notification_failed',
      offerId: offerId,
      reason: error.runtimeType.toString(),
    );
    return RiderOfferAlertOutcome.failed;
  }
  riderOfferLog('local_notification_posted', offerId: offerId);
  return RiderOfferAlertOutcome.posted;
}

Future<bool?> _notificationsAllowed({required bool requestIfNeeded}) async {
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin == null) {
    riderOfferLog('notification_permission', reason: 'android_plugin_unavailable');
    return null;
  }
  try {
    final bool? enabled = await androidPlugin.areNotificationsEnabled();
    if (enabled == true) {
      riderOfferLog('notification_permission', reason: 'granted');
      return true;
    }
    riderOfferLog('notification_permission', reason: 'denied');
    if (!requestIfNeeded) {
      return false;
    }
    final bool? granted = await androidPlugin.requestNotificationsPermission();
    riderOfferLog(
      'notification_permission',
      reason: granted == true ? 'granted_after_request' : 'denied_after_request',
    );
    return granted == true;
  } catch (error) {
    riderOfferLog(
      'notification_permission',
      reason: 'check_failed_${error.runtimeType}',
    );
    return null;
  }
}

Future<void> cancelRiderOfferAlert(String? offerId) async {
  final String id = (offerId ?? '').trim();
  if (id.isEmpty) {
    return;
  }
  _alertedOfferIds.remove(id);
  if (!_ready) {
    return;
  }
  await _plugin.cancel(_notificationId(id));
}

Future<NotificationAppLaunchDetails?> riderOfferLaunchDetails() async {
  await ensureRiderOfferAlerts();
  return _plugin.getNotificationAppLaunchDetails();
}

Map<String, String> _stringData(Map<String, dynamic> raw) {
  final Map<String, String> data = <String, String>{};
  raw.forEach((String key, dynamic value) {
    if (value != null) {
      data[key] = value.toString();
    }
  });
  return data;
}

String _alertBody(Map<String, String> data) {
  final String pickup = (data['pickup_address'] ?? '').trim();
  final String drop = (data['drop_address'] ?? '').trim();
  final double? km = double.tryParse(data['distance_km'] ?? '');
  final int seconds =
      int.tryParse(data['estimated_duration_seconds'] ?? '') ?? 0;
  final String? fare = _fareLabel(data['trip_fare']);
  final List<String> lines = <String>[
    if (pickup.isNotEmpty) 'Pickup: $pickup',
    if (drop.isNotEmpty) 'Drop: $drop',
    if (km != null) 'Distance: ${formatTripDistanceKm(km)}',
    if (seconds > 0) 'Time: ${_minutesLabel(seconds)}',
    if (fare != null) 'Trip fare: $fare',
  ];
  if (lines.isEmpty) {
    return (data['body'] ?? '').trim().isEmpty
        ? 'A new delivery request is waiting.'
        : data['body']!.trim();
  }
  return lines.join('\n');
}

String? _fareLabel(String? raw) {
  final double? amount = double.tryParse((raw ?? '').trim());
  if (amount == null || amount <= 0) {
    return null;
  }
  return '₹${amount.toStringAsFixed(0)}';
}

String _minutesLabel(int seconds) {
  final int minutes = (seconds / 60).ceil();
  final RiderOrder probe = RiderOrder(
    id: '',
    pickup: '',
    drop: '',
    distanceKm: 0,
    estimatedEarnings: 0,
    estimatedMinutes: minutes,
    customerMaskedName: '',
    customerMaskedPhone: '',
  );
  return probe.etaLabel;
}

int _notificationId(String offerId) => offerId.hashCode & 0x7fffffff;
