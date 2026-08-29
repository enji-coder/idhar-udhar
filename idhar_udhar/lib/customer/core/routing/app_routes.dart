/// Centralized route path constants for GoRouter.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String profileSetup = '/profile-setup';
  static const String locationPermission = '/location-permission';

  static const String home = '/home';
  static const String dashboard = '/home/dashboard';
  static const String orders = '/home/orders';
  static const String wallet = '/home/wallet';
  static const String profile = '/home/profile';

  static const String bookPickup = '/book/pickup';
  static const String bookDrop = '/book/drop';
  static const String bookVehicle = '/book/vehicle';
  static const String bookPackage = '/book/package';
  static const String bookSummary = '/book/summary';
  static const String bookSearching = '/book/searching';
  static const String bookRiderAssigned = '/book/rider-assigned';
  static const String bookTracking = '/book/tracking';
  static const String bookCompleted = '/book/completed';

  static const String orderDetails = '/orders/:id';
  static const String profileEdit = '/profile/edit';
  static const String savedAddresses = '/profile/saved-addresses';
  static const String help = '/help';
  static const String notifications = '/profile/notifications';

  static String orderDetailsPath(String id) => '/orders/$id';
}
