import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  runApp(const ProviderScope(child: IdharUdharRiderApp()));
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
