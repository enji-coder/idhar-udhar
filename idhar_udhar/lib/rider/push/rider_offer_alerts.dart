import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rider_offer_launch/rider_offer_launch.dart';

import '../data/local/rider_prefs.dart';
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
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (error) {
    riderOfferLog(
      'firebase_background_init_failed',
      offerId: message.data['offer_id']?.toString(),
      reason: error.runtimeType.toString(),
    );
  }
  final Map<String, String> data = _stringData(message.data);
  try {
    await _postAlertThenBringForward(data);
  } catch (error) {
    riderOfferLog(
      'alert_failed',
      offerId: message.data['offer_id']?.toString(),
      reason: error.runtimeType.toString(),
    );
  }
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
      AndroidInitializationSettings('@drawable/ic_stat_offer');
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

/// Asks for Android 13+ notification permission while the app is in the foreground.
/// Background delivery cannot show the system dialog.
Future<void> requestRiderOfferNotificationPermission() async {
  await ensureRiderOfferAlerts();
  await _notificationsAllowed(requestIfNeeded: true);
}

Future<bool> riderFullScreenOffersAllowed() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }
  try {
    final bool? allowed =
        await _offerChannel.invokeMethod<bool>('canUseFullScreenIntent');
    return allowed ?? false;
  } on MissingPluginException {
    // The FCM background isolate has no activity channel. Still request the
    // full-screen intent; Android ignores it unless that access is granted.
    riderOfferLog('full_screen_intent', reason: 'channel_unavailable_requesting');
    return true;
  } catch (_) {
    return false;
  }
}

/// Reads and clears the offer id used to bring this activity forward.
/// A normal resume has no id and must not invent one.
Future<String?> consumeRiderOfferLaunchId() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  try {
    final String? offerId =
        await _offerChannel.invokeMethod<String>('consumeLaunchOfferId');
    final String id = (offerId ?? '').trim();
    return id.isEmpty ? null : id;
  } on MissingPluginException {
    return null;
  } catch (error) {
    riderOfferLog(
      'launch_offer_unavailable',
      reason: error.runtimeType.toString(),
    );
    return null;
  }
}

Future<void> _postAlertThenBringForward(Map<String, String> data) async {
  final String offerId = (data['offer_id'] ?? '').trim();
  final String? displaySkip = offerAlertSkipReason(
    offerId: offerId,
    expiresAtRaw: data['expires_at'],
    now: DateTime.now(),
  );
  if (displaySkip != null) {
    await showRiderOfferAlert(data, postSystemNotification: true);
    return;
  }
  final bool loggedIn;
  final bool online;
  try {
    loggedIn = await RiderPrefs.isLoggedIn();
    online = await RiderPrefs.isOnline();
  } catch (error) {
    riderOfferLog(
      'activity_launch_skipped',
      offerId: offerId,
      reason: error.runtimeType.toString(),
    );
    await showRiderOfferAlert(data, postSystemNotification: true);
    return;
  }
  final bool sessionAllows = riderOfferActivityLaunchSkipReason(
        notificationPosted: true,
        loggedIn: loggedIn,
        online: online,
      ) ==
      null;
  final bool overlayGranted = await _overlayGranted();
  final bool willLaunch = sessionAllows && overlayGranted;
  final bool fsiAllowed = await riderFullScreenOffersAllowed();
  if (!willLaunch) {
    riderOfferLog(
      'activity_launch_skipped',
      offerId: offerId,
      reason: sessionAllows
          ? (overlayGranted ? 'not_eligible' : 'overlay_not_granted')
          : (riderOfferActivityLaunchSkipReason(
                notificationPosted: true,
                loggedIn: loggedIn,
                online: online,
              ) ??
              'not_eligible'),
    );
  }
  // Post notification with FSI whenever the OS allows it. Activity launch is
  // a parallel path when overlay is granted — not a floating overlay window.
  final RiderOfferAlertOutcome outcome = await showRiderOfferAlert(
    data,
    postSystemNotification: true,
    fullScreenIntent: riderOfferPostsFullScreenIntent(
      willBringActivityForward: willLaunch,
      platformAllowsFullScreenIntent: fsiAllowed,
    ),
  );
  if (outcome != RiderOfferAlertOutcome.posted) {
    return;
  }
  if (!willLaunch) {
    riderOfferLog(
      'activity_launch_skipped',
      offerId: offerId,
      reason: 'notification_posted_fsi_only',
    );
    return;
  }
  try {
    final bool started = await RiderOfferLaunch.presentOffer(offerId);
    riderOfferLog(
      'activity_launch',
      offerId: offerId,
      reason: started ? 'started' : 'not_started',
    );
    if (!started) {
      riderOfferLog(
        'activity_launch_fallback',
        offerId: offerId,
        reason: fsiAllowed ? 'rely_on_full_screen_intent' : 'heads_up_only',
      );
    }
  } on MissingPluginException {
    riderOfferLog(
      'activity_launch_skipped',
      offerId: offerId,
      reason: 'channel_unavailable',
    );
  } catch (error) {
    riderOfferLog(
      'activity_launch_skipped',
      offerId: offerId,
      reason: error.runtimeType.toString(),
    );
  }
}

Future<bool> _overlayGranted() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }
  try {
    return await RiderOfferLaunch.canDrawOverlays();
  } on MissingPluginException {
    // Background isolate without the plugin registered: do not invent grant.
    riderOfferLog('overlay_check_failed', reason: 'channel_unavailable');
    return false;
  } catch (error) {
    riderOfferLog(
      'overlay_check_failed',
      reason: error.runtimeType.toString(),
    );
    return false;
  }
}

/// Repeated tring for one offer. Safe to call again for the same id.
///
/// The ring stream follows the device ringer. Silent mode plays nothing.
/// Vibrate mode vibrates without sound. Do Not Disturb is not bypassed:
/// the in-app tone does not play while an interruption filter is active.
/// A killed process stops the loop; the notification channel can still play
/// its one-shot sound when Android delivers the notification.
Future<bool> beginRiderOfferSound({
  required String offerId,
  String? expiresAtRaw,
}) async {
  final String id = offerId.trim();
  if (id.isEmpty || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }
  final DateTime? expiresAt = DateTime.tryParse((expiresAtRaw ?? '').trim());
  if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
    return false;
  }
  try {
    final bool started = await RiderOfferLaunch.startOfferAlert(
      offerId: id,
      expiresAtMillis: expiresAt?.millisecondsSinceEpoch,
    );
    riderOfferLog(
      started ? 'offer_sound_started' : 'offer_sound_skipped',
      offerId: id,
    );
    return started;
  } on MissingPluginException {
    riderOfferLog('offer_sound_skipped', offerId: id, reason: 'channel_unavailable');
    return false;
  } catch (error) {
    riderOfferLog(
      'offer_sound_failed',
      offerId: id,
      reason: error.runtimeType.toString(),
    );
    return false;
  }
}

Future<void> endRiderOfferSound(String? offerId) async {
  final String id = (offerId ?? '').trim();
  if (id.isEmpty || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  try {
    await RiderOfferLaunch.stopOfferAlert(id);
    riderOfferLog('offer_sound_stopped', offerId: id);
  } on MissingPluginException {
    return;
  } catch (error) {
    riderOfferLog(
      'offer_sound_stop_failed',
      offerId: id,
      reason: error.runtimeType.toString(),
    );
  }
}

Future<void> playRiderOfferTick() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  try {
    await RiderOfferLaunch.playOfferTick();
  } on MissingPluginException {
    return;
  } catch (_) {
    // A missed tick must not break the countdown.
  }
}

Future<void> setRiderOfferScreenAwake(bool awake) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  try {
    await _offerChannel.invokeMethod<void>(
      'setOfferScreenAwake',
      <String, bool>{'awake': awake},
    );
  } on MissingPluginException {
    return;
  } catch (error) {
    riderOfferLog(
      'offer_screen_awake_failed',
      reason: error.runtimeType.toString(),
    );
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
  bool? fullScreenIntent,
}) async {
  final String offerId = (data['offer_id'] ?? '').trim();
  final String? skip = offerAlertSkipReason(
    offerId: offerId,
    expiresAtRaw: data['expires_at'],
    now: DateTime.now(),
  );
  if (skip != null) {
    riderOfferLog('alert_skipped', offerId: offerId, reason: skip);
    return RiderOfferAlertOutcome.skipped;
  }
  if (_alertedOfferIds.contains(offerId)) {
    riderOfferLog('alert_skipped', offerId: offerId, reason: 'duplicate_alert');
    return RiderOfferAlertOutcome.skipped;
  }
  final DateTime? expiresAt = DateTime.tryParse((data['expires_at'] ?? '').trim());
  final OfferNotificationWindow window =
      offerNotificationWindow(expiresAt, DateTime.now());
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
  final bool fsiAllowed =
      fullScreenIntent ?? await riderFullScreenOffersAllowed();
  riderOfferLog(
    'local_notification_posting',
    offerId: offerId,
    reason: fsiAllowed ? 'full_screen_intent_allowed' : 'full_screen_intent_denied_heads_up',
  );
  final String title = (data['title'] ?? '').trim().isEmpty
      ? 'New delivery request'
      : data['title']!.trim();
  _alertedOfferIds.add(offerId);
  // In-app loop is the repeated tring. The channel still plays its one-shot
  // sound for a heads-up when the process cannot keep the loop running.
  await beginRiderOfferSound(
    offerId: offerId,
    expiresAtRaw: data['expires_at'],
  );
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
        // Acceptance is the slide control on that screen, not a notification tap.
        fullScreenIntent: fsiAllowed,
        timeoutAfter: window.timeoutAfterMs,
        playSound: true,
        enableVibration: true,
        ticker: 'New delivery request',
        styleInformation: BigTextStyleInformation(_alertBody(data)),
      ),
    ),
    payload: offerId,
    );
  } catch (error) {
    _alertedOfferIds.remove(offerId);
    await endRiderOfferSound(offerId);
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
  await endRiderOfferSound(id);
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

String _alertBody(Map<String, String> data) => riderOfferNotificationBody(data);

Future<void> openRiderOfferChannelSettings() async {
  await ensureRiderOfferAlerts();
  try {
    await _offerChannel.invokeMethod<void>('openOfferChannelSettings');
  } catch (error) {
    riderOfferLog(
      'channel_settings_failed',
      reason: error.runtimeType.toString(),
    );
  }
}

int _notificationId(String offerId) => offerId.hashCode & 0x7fffffff;
