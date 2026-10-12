import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/custom_snack_bar.dart';
import '../routing/app_routes.dart';
import '../state/session_provider.dart';

bool customerFirebaseReady = false;

@pragma('vm:entry-point')
Future<void> customerFirebaseBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

/// Foreground display, tap, and cold-start routing for customer FCM messages.
class CustomerPushListener extends ConsumerStatefulWidget {
  const CustomerPushListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CustomerPushListener> createState() =>
      _CustomerPushListenerState();
}

class _CustomerPushListenerState extends ConsumerState<CustomerPushListener> {
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  RemoteMessage? _pending;
  bool _initialHandled = false;

  @override
  void initState() {
    super.initState();
    if (!customerFirebaseReady) {
      return;
    }
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    _foreground = FirebaseMessaging.onMessage.listen(_onForeground);
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeInitial(messaging));
    });
  }

  Future<void> _consumeInitial(FirebaseMessaging messaging) async {
    if (_initialHandled) {
      return;
    }
    _initialHandled = true;
    try {
      final RemoteMessage? initial = await messaging.getInitialMessage();
      if (initial != null) {
        _onOpened(initial);
      }
    } catch (_) {}
  }

  void _onForeground(RemoteMessage message) {
    final String title = (message.notification?.title ?? '').trim();
    final String body = (message.notification?.body ?? '').trim();
    final String text = title.isEmpty
        ? (body.isEmpty ? 'New notification' : body)
        : (body.isEmpty ? title : '$title\n$body');
    if (mounted) {
      CustomSnackBar.show(context, message: text);
    }
    if (ref.read(sessionProvider).isAuthenticated) {
      unawaited(ref.read(sessionProvider.notifier).refreshNotices());
    }
  }

  void _onOpened(RemoteMessage message) {
    if (!ref.read(sessionProvider).isAuthenticated) {
      _pending = message;
      return;
    }
    unawaited(_open(message));
  }

  Future<void> _open(RemoteMessage message) async {
    final String notificationId = _dataValue(message, 'notification_id');
    final String orderId = _dataValue(message, 'order_id');
    if (notificationId.isNotEmpty) {
      try {
        await ref.read(sessionProvider.notifier).markNoticeRead(notificationId);
      } catch (_) {}
    } else if (ref.read(sessionProvider).isAuthenticated) {
      try {
        await ref.read(sessionProvider.notifier).refreshNotices();
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    if (orderId.isNotEmpty) {
      context.go(AppRoutes.orderDetailsPath(orderId));
      return;
    }
    unawaited(context.push(AppRoutes.notifications));
  }

  String _dataValue(RemoteMessage message, String key) {
    final Object? value = message.data[key];
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  @override
  void dispose() {
    _foreground?.cancel();
    _opened?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState>(sessionProvider, (SessionState? previous, SessionState next) {
      final RemoteMessage? pending = _pending;
      if (pending == null || !next.isAuthenticated) {
        return;
      }
      _pending = null;
      unawaited(_open(pending));
    });
    return widget.child;
  }
}
