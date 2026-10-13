import 'dart:async';



import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:idhar_udhar/shared/api/api_exception.dart';

import 'package:idhar_udhar/shared/api/api_providers.dart';

import 'package:idhar_udhar/shared/api/order_mapper.dart';

import 'package:idhar_udhar/shared/api/rider_api.dart';



import '../data/dummy/dummy_rider_repository.dart';

import '../data/dummy/rider_finance.dart';

import '../data/models/rider_order.dart';

import '../routing/rider_router.dart';

import '../routing/rider_routes.dart';

import '../state/rider_session.dart';

import '../widgets/rider_order_alert.dart';

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

  String? _openDialogOfferId;

  String? _routeAfterDialog;

  /// Offer id from a background activity launch. While set, no other offer is opened.
  String? _targetedOfferId;



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

        if (request.action == 'open') {

          _targetedOfferId = request.offerId;

        }

        unawaited(

          _refreshAndPresent(

            fromNotification: request.action != 'open',

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

    } catch (error) {

      riderOfferLog('initial_message_failed', reason: error.runtimeType.toString());

    }

    try {

      await _consumeLocalLaunch();

    } catch (error) {

      riderOfferLog('local_launch_failed', reason: error.runtimeType.toString());

    }

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

    final bool showDialog = riderOfferUsesForegroundDialog(

      openedFromNotification: fromNotification,

      appResumed: inForeground,

    );

    riderOfferLog(

      fromNotification ? 'fcm_opened_app' : 'fcm_foreground_received',

      offerId: offerId.isEmpty ? null : offerId,

      reason:

          '${message.notification == null ? 'data' : 'notification'}_${inForeground ? 'app_resumed' : 'app_not_resumed'}',

    );

    var alertPlayed = false;

    if (showDialog) {

      final RiderOfferAlertOutcome outcome = await showRiderOfferAlert(

        data,

        postSystemNotification: true,

      );

      alertPlayed = outcome == RiderOfferAlertOutcome.posted;

      if (outcome == RiderOfferAlertOutcome.permissionDenied) {

        riderOfferLog('notification_permission', reason: 'denied_offer_not_posted');

      }

    }

    await _refreshAndPresent(

      fromNotification: !showDialog,

      offerId: offerId.isEmpty ? null : offerId,

      force: !showDialog,

      playFallbackSound: showDialog && !alertPlayed,

    );

  }



  bool _appInForeground() {

    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;

    return state == AppLifecycleState.resumed;

  }



  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.resumed) {

      unawaited(_presentOnResume());

    }

  }



  Future<void> _presentOnResume() async {

    final String? launched = await consumeRiderOfferLaunchId();

    if (launched != null) {

      _targetedOfferId = launched;

    }

    await _refreshAndPresent(

      fromNotification: false,

      offerId: _targetedOfferId,

    );

    if (ref.read(riderSessionProvider).isAuthenticated) {

      _targetedOfferId = null;

    }

  }



  Future<void> _refreshAndPresent({

    required bool fromNotification,

    String? offerId,

    bool force = false,

    int attempt = 0,

    bool playFallbackSound = false,

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

          playFallbackSound: playFallbackSound,

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

    if (!fromNotification && _appInForeground()) {

      await _presentForegroundDialog(

        offer,

        playFallbackSound: playFallbackSound,

      );

      return;

    }

    await _pushIncomingScreen(offer.offerId, force: force || fromNotification);

  }



  Future<void> _pushIncomingScreen(String offerId, {required bool force}) async {

    if (_openDialogOfferId == offerId) {

      riderOfferLog('present_already_open', offerId: offerId);

      return;

    }

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



  Future<void> _presentForegroundDialog(

    RiderOffer offer, {

    bool playFallbackSound = false,

  }) async {

    if (!mounted) {

      return;

    }

    if (_openDialogOfferId == offer.offerId || _presented.contains(offer.offerId)) {

      riderOfferLog('dialog_skipped_duplicate', offerId: offer.offerId);

      return;

    }

    final DateTime? expiresAt = offer.expiresAt;

    if (offer.status != 'PENDING' ||

        (expiresAt != null && !expiresAt.isAfter(DateTime.now()))) {

      unawaited(cancelRiderOfferAlert(offer.offerId));

      riderOfferLog('dialog_skipped', offerId: offer.offerId, reason: 'not_actionable');

      return;

    }

    _presented.add(offer.offerId);

    _openDialogOfferId = offer.offerId;

    riderOfferLog('dialog_opening', offerId: offer.offerId);

    final RiderOrder order = OrderMapper.toRiderOrder(offer: offer);

    try {

      await RiderOrderAlert.show(

        context,

        order: order,

        playFallbackSound: playFallbackSound,

        onExpired: () {

          unawaited(cancelRiderOfferAlert(offer.offerId));

          riderOfferLog('dialog_expired', offerId: offer.offerId);

        },

        onAccept: () => _acceptDialog(offer),

        onReject: () => _rejectDialog(offer),

      );

    } catch (error) {

      _presented.remove(offer.offerId);

      riderOfferLog(

        'dialog_failed',

        offerId: offer.offerId,

        reason: error.runtimeType.toString(),

      );

    } finally {

      if (_openDialogOfferId == offer.offerId) {

        _openDialogOfferId = null;

      }

      final String? route = _routeAfterDialog;

      _routeAfterDialog = null;

      if (route != null && mounted) {

        RiderRouter.config.go(route);

      }

    }

  }



  Future<String?> _acceptDialog(RiderOffer offer) async {

    final RiderSessionState session = ref.read(riderSessionProvider);

    if (!session.isApproved) {

      return 'Your profile must be approved before you can accept orders.';

    }

    if (riderIsSuspended(ref)) {

      return 'Account suspended until COD Due is cleared.';

    }

    if (!ref.read(riderOnlineProvider)) {

      return 'Go online to accept delivery requests.';

    }

    try {

      final accepted = await ref.read(riderApiProvider).acceptOffer(offer.offerId);

      if (!mounted) {

        return null;

      }

      var details = accepted;

      if (accepted.orderId.isNotEmpty) {

        try {

          details = await ref.read(riderApiProvider).getOrder(accepted.orderId);

        } on ApiException catch (error) {

          riderOfferLog(

            'order_details_failed',

            offerId: offer.offerId,

            reason: error.code,

          );

        } catch (error) {

          riderOfferLog(

            'order_details_failed',

            offerId: offer.offerId,

            reason: error.runtimeType.toString(),

          );

        }

      }

      ref.read(activeOrderProvider.notifier).state = OrderMapper.toRiderOrder(

        offer: acceptedOfferState(active: offer, order: details),

        order: details,

      );

      ref.read(deliveryStatusProvider.notifier).state =

          DeliveryLifecycleStatus.accepted;

      unawaited(cancelRiderOfferAlert(offer.offerId));

      _routeAfterDialog = RiderRoutes.orderDetails;

      riderOfferLog('accept_result', offerId: offer.offerId, reason: 'ok');

      return null;

    } on ApiException catch (error) {

      riderOfferLog('accept_result', offerId: offer.offerId, reason: error.code);

      unawaited(ref.read(riderSessionProvider.notifier).refreshOffers());

      return error.message;

    }

  }



  Future<String?> _rejectDialog(RiderOffer offer) async {

    try {

      await ref.read(riderApiProvider).rejectOffer(offer.offerId);

      unawaited(cancelRiderOfferAlert(offer.offerId));

      riderOfferLog('reject_result', offerId: offer.offerId, reason: 'ok');

      return null;

    } on ApiException catch (error) {

      riderOfferLog('reject_result', offerId: offer.offerId, reason: error.code);

      unawaited(ref.read(riderSessionProvider.notifier).refreshOffers());

      return error.message;

    } catch (error) {

      riderOfferLog(

        'reject_result',

        offerId: offer.offerId,

        reason: error.runtimeType.toString(),

      );

      return 'Could not reject this request. Try again.';

    }

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

      final String? targeted = _targetedOfferId;

      if ((targeted ?? '').isNotEmpty && !_appInForeground()) {

        return;

      }

      final RiderOffer? offer = (targeted ?? '').isNotEmpty

          ? riderOfferById(next.offers, targeted)

          : _pendingOffer(next.offers);

      if ((targeted ?? '').isNotEmpty && offer == null) {

        return;

      }

      if ((targeted ?? '').isNotEmpty) {

        _targetedOfferId = null;

      }

      if (offer == null || _presented.contains(offer.offerId)) {

        return;

      }

      final String path =

          RiderRouter.config.routerDelegate.currentConfiguration.uri.path;

      if (path == RiderRoutes.incomingOrder) {

        _presented.add(offer.offerId);

        return;

      }

      if (_appInForeground()) {

        unawaited(_presentForegroundDialog(offer));

      } else {

        unawaited(_pushIncomingScreen(offer.offerId, force: false));

      }

    });

    return widget.child;

  }

}



/// Set from rider startup after Firebase initialization.

bool riderFirebaseReady = false;


