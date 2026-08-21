/// Rider asset path constants (Rider flavor only).
/// Structured folders under assets/rider/images/* are ready for future assets.
abstract final class RiderAssets {
  static const String logo = 'assets/rider/logos/idhar_udhar_logo.png';

  /// Premium 3D delivery scooter for Rider splash / onboarding.
  static const String deliveryScooter =
      'assets/rider/images/rider_delivery_scooter.png';

  /// Legacy alias — prefer [deliveryScooter].
  static const String deliveryBike = deliveryScooter;

  static const String onboardingDir = 'assets/rider/images/onboarding/';
  static const String profileDir = 'assets/rider/images/profile/';
  static const String vehicleDir = 'assets/rider/images/vehicle/';
  static const String documentsDir = 'assets/rider/images/documents/';
  static const String ordersDir = 'assets/rider/images/orders/';
  static const String navigationDir = 'assets/rider/images/navigation/';
  static const String paymentDir = 'assets/rider/images/payment/';
  static const String safetyDir = 'assets/rider/images/safety/';
  static const String dashboardDir = 'assets/rider/images/dashboard/';
}
