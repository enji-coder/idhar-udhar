import 'dart:async';



import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:idhar_udhar/shared/api/rider_api.dart';

import 'package:permission_handler/permission_handler.dart';



import '../routing/rider_router.dart';

import '../routing/rider_routes.dart';

import '../state/rider_session.dart';

import 'rider_offer_alerts.dart';

import 'rider_offer_diag.dart';



/// Opens one incoming-offer screen for a pending offer and posts the alert.

class RiderOfferListener extends ConsumerStatefulWidget {

  const RiderOfferListener({required this.child, super.key});



  final Widget child;



  @override

  ConsumerState<RiderOfferListener> createState() => _RiderOfferListenerState();

}



class _RiderOfferListenerState extends ConsumerState<RiderOfferListener>

    with WidgetsBindingObserver {

  StreamSubscription<RemoteMessage>? _foreground;

  StreamSubscription<RemoteMessage>? _opened;

  StreamSubscription<RiderOfferUserAction>? _actions;

  StreamSubscription<RiderOfferPresentRequest>? _presentRequests;

  final Set<String> _presented = <String>{};

  bool _offeredNotificationSettings = false;



  static const int _maxOfferFetchAttempts = 6;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addObserver(this);

    unawaited(ensureRiderOfferAlerts());

    _actions = riderOfferUserActions.listen((RiderOfferUserAction action) {

      unawaited(_openForAction(action.offerId));

    });

    _presentRequests = riderOfferPresentRequests.listen(

      (RiderOfferPresentRequest request) {

        unawaited(

          _refreshAndPresent(

            fromNotification: true,

            offerId: request.offerId,

            force: request.action == 'open',

          ),

        );

      },

    );

    if (!riderFirebaseReady) {

      riderOfferLog('listener_init', reason: 'firebase_not_ready');

      WidgetsBinding.instance.addPostFrameCallback((_) {

        unawaited(_consumeLocalLaunch());

      });

      return;

    }

    riderOfferLog('listener_init', reason: 'firebase_ready');

    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    _foreground = FirebaseMessaging.onMessage.listen(

      (RemoteMessage message) => _onMessage(message, fromNotification: false),

    );

    _opened = FirebaseMessaging.onMessageOpenedApp.listen(

      (RemoteMessage message) => _onMessage(message, fromNotification: true),

    );

    WidgetsBinding.instance.addPostFrameCallback((_) {

      unawaited(_consumeLaunch(messaging));

    });

  }



  Future<void> _consumeLaunch(FirebaseMessaging messaging) async {

    try {

      final RemoteMessage? initial = await messaging.getInitialMessage();

      if (initial != null) {

        await _onMessage(initial, fromNotification: true);

      }

    } catch (_) {}

    try {

      await _consumeLocalLaunch();

    } catch (_) {}

  }



  Future<void> _consumeLocalLaunch() async {

    final NotificationAppLaunchDetails? launch = await riderOfferLaunchDetails();

    final String? offerId = launch?.notificationResponse?.payload;

    if (launch?.didNotificationLaunchApp != true ||

        offerId == null ||

        offerId.isEmpty) {

      return;

    }

    final String action = launch?.notificationResponse?.actionId ?? 'open';

    riderOfferLog('local_launch', offerId: offerId, reason: action);

    deliverRiderOfferNotification(offerId: offerId, action: action);

  }



  Future<void> _openForAction(String offerId) async {

    if (!mounted || offerId.isEmpty) {

      return;

    }

    await _refreshAndPresent(

      fromNotification: true,

      offerId: offerId,

      force: true,

    );

  }



  Future<void> _onMessage(

    RemoteMessage message, {

    required bool fromNotification,

  }) async {

    if (message.data['type'] != 'OFFER_NEW') {

      return;

    }

    final Map<String, String> data = <String, String>{};

    message.data.forEach((String key, dynamic value) {

      if (value != null) {

        data[key] = value.toString();

      }

    });

    final String offerId = (data['offer_id'] ?? '').trim();

    final bool inForeground = _appInForeground();

    riderOfferLog(

      fromNotification ? 'fcm_opened_app' : 'fcm_foreground_received',

      offerId: offerId.isEmpty ? null : offerId,

      reason: inForeground ? 'app_resumed' : 'app_not_resumed',

    );

    if (!fromNotification) {

      final RiderOfferAlertOutcome outcome = await showRiderOfferAlert(

        data,

        postSystemNotification: true,

        requestPermissionIfNeeded: true,

      );

      if (outcome == RiderOfferAlertOutcome.permissionDenied) {

        await _openNotificationSettings();

      }

    }

    await _refreshAndPresent(

      fromNotification: true,

      offerId: offerId.isEmpty ? null : offerId,

      force: true,

    );

  }



  Future<void> _openNotificationSettings() async {

    if (!mounted || _offeredNotificationSettings) {

      riderOfferLog(

        'notification_permission',

        reason: _offeredNotificationSettings

            ? 'settings_already_offered'

            : 'settings_skipped_unmounted',

      );

      return;

    }

    _offeredNotificationSettings = true;

    riderOfferLog('notification_permission', reason: 'opening_app_settings');

    try {

      final bool opened = await openAppSettings();

      if (!opened) {

        riderOfferLog('notification_permission', reason: 'settings_not_opened');

      }

    } catch (_) {

      riderOfferLog('notification_permission', reason: 'settings_unavailable');

    }

  }



  bool _appInForeground() {

    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;

    return state == AppLifecycleState.resumed;

  }



  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.resumed) {

      unawaited(_refreshAndPresent(fromNotification: false));

    }

  }



  Future<void> _refreshAndPresent({

    required bool fromNotification,

    String? offerId,

    bool force = false,

    int attempt = 0,

  }) async {

    final RiderSessionState session = ref.read(riderSessionProvider);

    if (!session.isAuthenticated) {

      riderOfferLog('present_blocked', offerId: offerId, reason: 'not_authenticated');

      return;

    }

    if (session.onlineStatus != 'ONLINE') {

      riderOfferLog('present_blocked', offerId: offerId, reason: 'not_online');

      return;

    }

    try {

      await ref.read(riderSessionProvider.notifier).refreshOffers();

    } catch (_) {

      riderOfferLog('present_blocked', offerId: offerId, reason: 'refresh_offers_failed');

      return;

    }

    if (!mounted) {

      return;

    }

    final List<RiderOffer> offers = ref.read(riderSessionProvider).offers;

    final RiderOffer? offer = (offerId ?? '').trim().isEmpty

        ? _pendingOffer(offers)

        : riderOfferById(offers, offerId);

    if (offer == null) {

      if ((offerId ?? '').trim().isNotEmpty && attempt < _maxOfferFetchAttempts) {

        riderOfferLog(

          'present_retry',

          offerId: offerId,

          reason: 'offer_not_in_list_attempt_${attempt + 1}',

        );

        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));

        if (!mounted) {

          return;

        }

        return _refreshAndPresent(

          fromNotification: fromNotification,

          offerId: offerId,

          force: force,

          attempt: attempt + 1,

        );

      }

      if ((offerId ?? '').trim().isNotEmpty && fromNotification) {

        riderOfferLog('present_blocked', offerId: offerId, reason: 'offer_not_found');

        await _pushIncomingScreen(offerId!.trim(), force: true);

      }

      return;

    }

    final DateTime? expiresAt = offer.expiresAt;

    if (offer.status != 'PENDING' ||

        (expiresAt != null && !expiresAt.isAfter(DateTime.now()))) {

      unawaited(cancelRiderOfferAlert(offer.offerId));

      riderOfferLog(

        'present_blocked',

        offerId: offer.offerId,

        reason: offer.status != 'PENDING' ? 'not_pending' : 'expired',

      );

      return;

    }

    await _pushIncomingScreen(offer.offerId, force: force || fromNotification);

  }



  Future<void> _pushIncomingScreen(String offerId, {required bool force}) async {

    final String path =

        RiderRouter.config.routerDelegate.currentConfiguration.uri.path;

    if (path == RiderRoutes.incomingOrder) {

      _presented.add(offerId);

      riderOfferLog('present_already_open', offerId: offerId);

      return;

    }

    if (_presented.contains(offerId) && !force) {

      riderOfferLog('present_skipped_duplicate', offerId: offerId);

      return;

    }

    _presented.add(offerId);

    riderOfferLog('incoming_screen_opening', offerId: offerId);

    try {

      await RiderRouter.config.push(RiderRoutes.incomingOrder);

      riderOfferLog('incoming_screen_opened', offerId: offerId);

    } catch (error) {

      _presented.remove(offerId);

      riderOfferLog('incoming_screen_failed', offerId: offerId, reason: '$error');

    }

  }



  RiderOffer? _pendingOffer(List<RiderOffer> offers) {

    for (final RiderOffer offer in offers) {

      if (offer.status != 'PENDING') {

        continue;

      }

      final DateTime? expiresAt = offer.expiresAt;

      if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {

        unawaited(cancelRiderOfferAlert(offer.offerId));

        continue;

      }

      return offer;

    }

    return null;

  }



  @override

  void dispose() {

    WidgetsBinding.instance.removeObserver(this);

    _actions?.cancel();

    _presentRequests?.cancel();

    _foreground?.cancel();

    _opened?.cancel();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    ref.listen<RiderSessionState>(riderSessionProvider, (

      RiderSessionState? previous,

      RiderSessionState next,

    ) {

      if (next.onlineStatus != 'ONLINE' || !next.isAuthenticated) {

        return;

      }

      final RiderOffer? offer = _pendingOffer(next.offers);

      if (offer == null || _presented.contains(offer.offerId)) {

        return;

      }

      final String path =

          RiderRouter.config.routerDelegate.currentConfiguration.uri.path;

      if (path == RiderRoutes.incomingOrder) {

        _presented.add(offer.offerId);

        return;

      }

      unawaited(_pushIncomingScreen(offer.offerId, force: false));

    });

    return widget.child;

  }

}



/// Set from rider startup after Firebase initialization.

bool riderFirebaseReady = false;


