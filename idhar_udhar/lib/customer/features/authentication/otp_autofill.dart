import 'dart:io';

import 'package:flutter/services.dart';

/// Android SMS User Consent plus the platform one-time-code autofill hint.
///
/// The consent sheet shows one message. It does not read the SMS inbox.
class CustomerOtpAutofill {
  CustomerOtpAutofill._();

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

  /// Starts listening before the OTP SMS is sent.
  static Future<void> arm() async {
    if (!Platform.isAndroid) {
      return;
    }
    _channel.setMethodCallHandler(_onCall);
    try {
      await _channel.invokeMethod<void>('start');
    } on MissingPluginException {
      // Non-customer Android builds do not register the consent channel.
    } on PlatformException {
      // Consent or Play Services is unavailable. Manual OTP entry continues.
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
      // Channel is absent outside the customer Android flavor.
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
