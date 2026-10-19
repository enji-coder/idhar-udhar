import 'package:flutter/services.dart';

/// Native bubble over other apps. No-ops in tests and when the channel is absent.
class RiderNavOverlay {
  RiderNavOverlay._();

  static const MethodChannel _channel =
      MethodChannel('idhar_udhar/nav_overlay');
  static void Function(String action)? _onAction;

  static void bind(void Function(String action) onAction) {
    _onAction = onAction;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onAction' && call.arguments is String) {
        _onAction?.call(call.arguments! as String);
      }
    });
  }

  static void unbind() {
    _onAction = null;
    _channel.setMethodCallHandler(null);
  }

  static Future<bool> canDrawOverlays() async {
    try {
      final bool? allowed =
          await _channel.invokeMethod<bool>('canDrawOverlays');
      return allowed ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod<void>('openOverlaySettings');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<String> launch({
    required String navigationUri,
    required String fallbackUri,
  }) async {
    try {
      final String? mode =
          await _channel.invokeMethod<String>('launch', <String, String>{
        'navigationUri': navigationUri,
        'fallbackUri': fallbackUri,
      });
      return mode ?? 'unavailable';
    } on MissingPluginException {
      return 'unavailable';
    } on PlatformException {
      return 'unavailable';
    }
  }

  static Future<void> arm() {
    return _invoke('arm');
  }

  /// Puts this task behind the task that was open before it. The order-details
  /// sheet does not use this; closing that sheet stays on the current trip.
  static Future<void> moveToBack() {
    return _invoke('moveToBack');
  }

  /// App is no longer visible. Ignored by native code while an app activity
  /// is still started, so an activity pause cannot reveal the bubble.
  static Future<void> noteBackground() {
    return _invoke('background');
  }

  /// App is visible again. Removes the window without ending the delivery.
  static Future<void> noteForeground() {
    return _invoke('foreground');
  }

  static Future<void> disarm() {
    return _invoke('disarm');
  }

  static Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<String?> consumeAction() async {
    try {
      return await _channel.invokeMethod<String>('consumeAction');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
