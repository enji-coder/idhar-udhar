import 'package:flutter/services.dart';

/// Asks Android to bring the existing Rider activity forward for one offer.
///
/// Registered on every Flutter engine, including the FCM background isolate.
/// The caller must already have posted the offer notification and decided the
/// rider is allowed to see this offer.
class RiderOfferLaunch {
  const RiderOfferLaunch._();

  static const MethodChannel _channel = MethodChannel(
    'com.idharudhar.rider/offer_launch',
  );

  static const String offerIdExtra = 'iu_offer_id';

  static Future<bool> canDrawOverlays() async {
    final bool? allowed = await _channel.invokeMethod<bool>('canDrawOverlays');
    return allowed == true;
  }

  static Future<bool> presentOffer(String offerId) async {
    final bool? started = await _channel.invokeMethod<bool>(
      'presentOffer',
      <String, String>{'offerId': offerId},
    );
    return started == true;
  }

  /// Starts one repeated offer alert for [offerId]. A second call for the
  /// same id does not stack another loop. [expiresAtMillis] stops it even
  /// if the Flutter UI never opens.
  static Future<bool> startOfferAlert({
    required String offerId,
    int? expiresAtMillis,
  }) async {
    final Map<String, Object> args = <String, Object>{'offerId': offerId};
    if (expiresAtMillis != null) {
      args['expiresAtMillis'] = expiresAtMillis;
    }
    final bool? started =
        await _channel.invokeMethod<bool>('startOfferAlert', args);
    return started == true;
  }

  static Future<void> stopOfferAlert(String offerId) async {
    await _channel.invokeMethod<void>(
      'stopOfferAlert',
      <String, String>{'offerId': offerId},
    );
  }

  /// Short countdown tick. Ignored while a tring is still sounding.
  static Future<void> playOfferTick() async {
    await _channel.invokeMethod<void>('playOfferTick');
  }
}
