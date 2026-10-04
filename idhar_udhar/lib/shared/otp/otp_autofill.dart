import 'dart:io';

import 'package:flutter/services.dart';

/// Android SMS OTP helpers.
///
/// Rider uses the silent SMS Retriever API (no consent sheet). That path only
/// receives the SMS when the message includes the app hash.
/// Customer keeps SMS User Consent as a fallback that works without the hash.
class OtpAutofill {
  OtpAutofill._();

  static const MethodChannel _channel = MethodChannel(
    'com.idharudhar.idhar_udhar/otp_autofill',
  );

  static String? _pendingMessage;
  static void Function(String message)? _listener;

  /// Digits of [length] from an SMS body. Returns null when the code is absent.
  static String? exactOtpDigits(String message, int length) {
    if (length <= 0) {
      return null;
    }
    final RegExpMatch? match =
        RegExp('\\b(\\d{$length})\\b').firstMatch(message);
    return match?.group(1);
  }

  /// Silent SMS Retriever. Prefer for Rider when the SMS template includes the
  /// Android app hash.
  static Future<void> armRetriever() => _arm('startRetriever');

  /// SMS User Consent sheet. Used by Customer when silent retrieval is not
  /// guaranteed by the SMS template.
  static Future<void> armConsent() => _arm('startConsent');

  static Future<void> _arm(String method) async {
    if (!Platform.isAndroid) {
      return;
    }
    _channel.setMethodCallHandler(_onCall);
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Channel absent on unsupported builds.
    } on PlatformException {
      // Play Services unavailable. Manual OTP entry continues.
    }
  }

  static void listen(void Function(String message) listener) {
    _listener = listener;
    final String? pending = _pendingMessage;
    _pendingMessage = null;
    if (pending != null) {
      listener(pending);
    }
  }

  static Future<void> stop() async {
    _listener = null;
    _pendingMessage = null;
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Channel is absent outside Android builds that register it.
    } on PlatformException {
      // Stopping a listener that never started is not an error.
    }
  }

  static Future<void> _onCall(MethodCall call) async {
    if (call.method != 'onSms' || call.arguments is! String) {
      return;
    }
    final String message = call.arguments as String;
    final void Function(String message)? listener = _listener;
    if (listener == null) {
      _pendingMessage = message;
      return;
    }
    listener(message);
  }
}

/// Compatibility wrapper for existing Customer call sites.
class CustomerOtpAutofill {
  CustomerOtpAutofill._();

  static String? exactOtpDigits(String message, int length) =>
      OtpAutofill.exactOtpDigits(message, length);

  static Future<void> arm() => OtpAutofill.armConsent();

  static void listen(void Function(String message) listener) =>
      OtpAutofill.listen(listener);

  static Future<void> stop() => OtpAutofill.stop();
}
