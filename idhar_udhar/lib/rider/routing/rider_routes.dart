/// Rider route paths — isolated from Customer [AppRoutes].
abstract final class RiderRoutes {
  static const String splash = '/rider/splash';
  static const String login = '/rider/login';
  static const String terms = '/rider/onboarding/terms';

  // Registration / onboarding
  static const String registrationWelcome = '/rider/registration/welcome';
  static const String mobileVerification = '/rider/registration/mobile';
  static const String otpVerification = '/rider/registration/otp';
  static const String profileSetup = '/rider/registration/profile';
  static const String vehicleType = '/rider/registration/vehicle-type';
  static const String vehicleDetails = '/rider/registration/vehicle-details';
  static const String driverDetails = '/rider/registration/driver-details';
  static const String documents = '/rider/registration/documents';
  static const String bankUpi = '/rider/registration/bank-upi';
  static const String verificationStatus = '/rider/registration/verification';
  static const String permissionSetup = '/rider/registration/permissions';
  static const String registrationComplete = '/rider/registration/complete';

  // Rider app
  static const String dashboard = '/rider/dashboard';
  static const String incomingOrder = '/rider/orders/incoming';
  static const String acceptConfirmation = '/rider/orders/accepted';
  static const String orderDetails = '/rider/orders/details';
  static const String activeDelivery = '/rider/orders/active';
  static const String profile = '/rider/profile';
  static const String vehicleEdit = '/rider/vehicle/edit';
  static const String bankEdit = '/rider/bank/edit';
  static const String upiDetails = '/rider/upi';
  static const String documentsReview = '/rider/documents';
  static const String wallet = '/rider/wallet';
  static const String income = '/rider/income';
  static const String history = '/rider/history';
  static const String settings = '/rider/settings';
  static const String notifications = '/rider/notifications';
}
