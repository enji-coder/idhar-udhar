import 'dart:io';

import 'package:flutter/foundation.dart';

/// Environment checks for Google Maps / location. Never logs secrets.
abstract final class MapsRuntime {
  static bool get isFlutterTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static bool get useGoogleMapWidget =>
      !kIsWeb && !isFlutterTest && (Platform.isAndroid || Platform.isIOS);

  static bool get useNativeLocation =>
      !kIsWeb && !isFlutterTest && Platform.isAndroid;
}
