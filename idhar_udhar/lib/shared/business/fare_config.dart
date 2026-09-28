/// Confirmed V1 maximum: 2 or 3 delivery locations (not including pickup).
abstract final class BookingLimits {
  static const int maxDeliveryStops = 3;
  static const int minMultiDeliveryStops = 2;
  static const bool maxStopsPendingBusinessDecision = false;
}
