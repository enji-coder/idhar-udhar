import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_config.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/push/firebase_fcm_token_source.dart';
import 'package:idhar_udhar/shared/push/push_token_sync.dart';

import 'routing/rider_router.dart';
import 'theme/rider_colors.dart';
import 'theme/rider_theme.dart';

/// Rider App entry (Splash → Login → Registration → Dashboard → Orders).
///
/// ```bash
/// flutter run --flavor rider -t lib/rider/rider_main.dart
/// ```
///
/// Isolated from Customer entry / router / theme.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.useProductionDefault();
  final bool firebaseReady = await _initializeRiderFirebase();

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        pushTokenSyncProvider.overrideWith((ref) {
          final PushTokenSync sync = PushTokenSync(
            ref.watch(deviceTokensApiProvider),
            tokens: firebaseReady ? FirebaseFcmTokenSource() : null,
            requireFirebase: true,
          );
          ref.onDispose(sync.dispose);
          return sync;
        }),
      ],
      child: const IdharUdharRiderApp(),
    ),
  );
}

/// One Android default app from the Rider flavor's google-services.json.
Future<bool> _initializeRiderFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    if (kDebugMode) {
      debugPrint('PUSH: Firebase already initialized');
    }
    return true;
  }
  try {
    await Firebase.initializeApp();
    if (kDebugMode) {
      debugPrint('PUSH: Firebase initialized');
    }
    return true;
  } catch (error) {
    if (kDebugMode) {
      debugPrint('PUSH: Firebase initialization failed: $error');
    }
    return false;
  }
}

class IdharUdharRiderApp extends StatelessWidget {
  const IdharUdharRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IDHAR UDHAR Rider',
      debugShowCheckedModeBanner: false,
      theme: RiderTheme.light,
      color: RiderColors.background,
      routerConfig: RiderRouter.config,
    );
  }
}
