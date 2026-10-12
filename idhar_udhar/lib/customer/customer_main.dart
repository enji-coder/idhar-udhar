import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/push/firebase_fcm_token_source.dart';
import 'package:idhar_udhar/shared/push/push_token_sync.dart';

import 'config/app_config.dart';
import 'config/environment.dart';
import 'core/push/customer_push.dart';
import 'core/routing/app_router.dart';
import 'core/state/startup_device_pickup.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  customerFirebaseReady = await _initializeCustomerFirebase();
  if (customerFirebaseReady) {
    FirebaseMessaging.onBackgroundMessage(customerFirebaseBackgroundHandler);
  }

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  Environment.initialize(AppEnvironment.development);

  runApp(
    ProviderScope(
      overrides: [
        pushTokenSyncProvider.overrideWith((ref) {
          final PushTokenSync sync = PushTokenSync(
            ref.watch(deviceTokensApiProvider),
            tokens: customerFirebaseReady ? FirebaseFcmTokenSource() : null,
            requireFirebase: true,
          );
          ref.onDispose(sync.dispose);
          return sync;
        }),
      ],
      child: const IdharUdharApp(),
    ),
  );
}

Future<bool> _initializeCustomerFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    return true;
  }
  try {
    await Firebase.initializeApp();
    return true;
  } catch (error) {
    if (kDebugMode) {
      debugPrint('PUSH: Firebase initialization failed: $error');
    }
    return false;
  }
}

class IdharUdharApp extends StatelessWidget {
  const IdharUdharApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StartupDevicePickup(
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: AppRouter.config,
        builder: (context, child) {
          return CustomerPushListener(
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
