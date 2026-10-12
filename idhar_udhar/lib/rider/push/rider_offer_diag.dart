import 'package:flutter/foundation.dart';

/// Safe, non-PII diagnostics for the rider incoming-offer flow (logcat / debug console).
void riderOfferLog(
  String stage, {
  String? offerId,
  String? reason,
}) {
  final String idSuffix = _safeOfferRef(offerId);
  final String reasonSuffix =
      reason == null || reason.isEmpty ? '' : ' reason=$reason';
  debugPrint('RIDER_OFFER: $stage$idSuffix$reasonSuffix');
}

String _safeOfferRef(String? offerId) {
  final String id = (offerId ?? '').trim();
  if (id.isEmpty) {
    return '';
  }
  if (id.length <= 8) {
    return ' offer=$id';
  }
  return ' offer=${id.substring(0, 8)}…';
}
