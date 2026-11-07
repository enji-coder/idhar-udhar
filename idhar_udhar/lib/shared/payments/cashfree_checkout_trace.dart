import 'package:flutter/foundation.dart';

/// Timing at our checkout boundaries. Never pass a session id, order token,
/// card, CVV, or OTP into [event] or [result].
///
/// Printed so a release APK still shows it in logcat under the flutter tag.
void traceCashfreeCheckout(String event, {int? elapsedMs, String? result}) {
  final String timing = elapsedMs == null ? '' : ' elapsed_ms=$elapsedMs';
  final String outcome = result == null ? '' : ' result=$result';
  debugPrint('cashfree_checkout $event$timing$outcome');
}
