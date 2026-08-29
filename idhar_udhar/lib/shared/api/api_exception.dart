/// Mapped Nest `/v1` error. [message] is always safe to show in existing UI.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.details,
    this.requestId,
    this.statusCode,
  });

  final String code;
  final String message;
  final Object? details;
  final String? requestId;
  final int? statusCode;

  bool get isUnauthenticated =>
      code == 'UNAUTHENTICATED' ||
      code == 'INVALID_TOKEN' ||
      code == 'INVALID_REFRESH_TOKEN' ||
      code == 'SESSION_REVOKED' ||
      code == 'SESSION_EXPIRED';

  @override
  String toString() {
    if (requestId == null || requestId!.isEmpty) {
      return 'ApiException($code)';
    }
    return 'ApiException($code, request_id=$requestId)';
  }
}

/// Turns backend `{ error: { code, message, details, request_id } }` into
/// user-facing copy. Never forwards SQL or raw database text.
abstract final class ApiErrorMapper {
  static const String _fallback = 'Something went wrong. Please try again.';

  static ApiException fromBody(
    Object? body, {
    int? statusCode,
    String? fallbackMessage,
  }) {
    final Map<String, Object?> root = body is Map
        ? <String, Object?>{
            for (final MapEntry<dynamic, dynamic> e in body.entries)
              e.key.toString(): e.value,
          }
        : <String, Object?>{};
    final Object? nested = root['error'];
    final Map<String, Object?> error = nested is Map
        ? <String, Object?>{
            for (final MapEntry<dynamic, dynamic> e in nested.entries)
              e.key.toString(): e.value,
          }
        : root;

    final Object? rawCode = error['code'];
    final String code = rawCode is String && rawCode.trim().isNotEmpty
        ? rawCode
        : _codeForStatus(statusCode);
    final Object? rawRequestId = error['request_id'];
    final String? requestId = rawRequestId is String ? rawRequestId : null;
    return ApiException(
      code: code,
      message: userMessage(code, error['message'], fallbackMessage),
      details: error['details'],
      requestId: requestId,
      statusCode: statusCode,
    );
  }

  static String userMessage(
    String code,
    Object? backendMessage, [
    String? fallback,
  ]) {
    final String mapped = _friendly[code] ?? '';
    if (mapped.isNotEmpty) {
      return mapped;
    }
    if (backendMessage is String) {
      final String trimmed = backendMessage.trim();
      if (trimmed.isNotEmpty && !_looksUnsafe(trimmed)) {
        return trimmed;
      }
    }
    return fallback ?? _fallback;
  }

  static bool _looksUnsafe(String message) {
    final String lower = message.toLowerCase();
    return lower.contains('sql') ||
        lower.contains('postgres') ||
        lower.contains('relation ') ||
        lower.contains('syntax error') ||
        lower.contains('stack') ||
        lower.contains('exception');
  }

  static String _codeForStatus(int? status) {
    switch (status) {
      case 400:
        return 'VALIDATION_ERROR';
      case 401:
        return 'UNAUTHENTICATED';
      case 403:
        return 'FORBIDDEN';
      case 404:
        return 'NOT_FOUND';
      case 429:
        return 'OTP_RATE_LIMITED';
      case 503:
        return 'DATABASE_UNAVAILABLE';
      default:
        return 'INTERNAL_ERROR';
    }
  }

  static const Map<String, String> _friendly = <String, String>{
    'OTP_INVALID': 'Invalid OTP. Please try again.',
    'OTP_EXPIRED': 'This code has expired. Request a new one.',
    'OTP_ALREADY_USED': 'This code was already used. Request a new one.',
    'OTP_NOT_FOUND': 'Request a new code and try again.',
    'OTP_COOLDOWN': 'Please wait before requesting another code.',
    'OTP_RATE_LIMITED': 'Too many attempts. Try again later.',
    'OTP_ATTEMPTS_EXCEEDED': 'Too many incorrect codes. Request a new one.',
    'UNAUTHENTICATED': 'Please sign in again.',
    'INVALID_TOKEN': 'Please sign in again.',
    'INVALID_REFRESH_TOKEN': 'Please sign in again.',
    'SESSION_REVOKED': 'Your session ended. Please sign in again.',
    'SESSION_EXPIRED': 'Your session expired. Please sign in again.',
    'IDENTITY_INACTIVE': 'This account is locked.',
    'FORBIDDEN': 'You cannot do that.',
    'NOT_FOUND': 'We could not find that.',
    'VALIDATION_ERROR': 'Please check the details and try again.',
    'CITY_INVALID': 'Delivery is not available for this city yet.',
    'VEHICLE_CATEGORY_INVALID': 'That vehicle is not available.',
    'INVALID_STOPS': 'Pickup and drop locations are incomplete.',
    'INVALID_COORDINATES': 'That location could not be used. Pick another pin.',
    'ROUTING_PROVIDER_UNAVAILABLE':
        'Could not calculate the route. Try again shortly.',
    'FARE_CONFIG_UNAVAILABLE': 'Fare is not available right now.',
    'QUOTE_EXPIRED': 'The fare expired. Confirm again to get a new fare.',
    'QUOTE_NOT_FOUND': 'The fare expired. Confirm again to get a new fare.',
    'ORDER_NOT_MODIFIABLE': 'This order cannot be changed.',
    'INVALID_TRANSITION': 'That order update is not allowed yet.',
    'OFFER_NOT_FOUND': 'This order is no longer available.',
    'OFFER_EXPIRED': 'This order offer expired.',
    'OFFER_NOT_PENDING': 'This order was already answered.',
    'ORDER_ALREADY_ACCEPTED': 'Another rider already accepted this order.',
    'RIDER_NOT_ELIGIBLE': 'You cannot accept orders right now.',
    'RIDER_HAS_ACTIVE_ORDER': 'Finish your current delivery first.',
    'WALLET_INSUFFICIENT': 'Wallet balance is not enough.',
    'COD_SETTLEMENT_EXCEEDS_DUE': 'That amount is more than COD Due.',
    'IDEMPOTENCY_KEY_REQUIRED': 'Please try that action again.',
    'IDEMPOTENCY_CONFLICT': 'Please try that action again.',
    'DATABASE_UNAVAILABLE': 'Service is temporarily unavailable.',
    'INTERNAL_ERROR': _fallback,
  };
}
