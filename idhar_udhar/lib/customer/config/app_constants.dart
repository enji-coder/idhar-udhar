/// Shared constant values used across the application foundation.
///
/// Keep this file free of feature-specific business rules.
abstract final class AppConstants {
  static const String brandOrangeHex = '#FF6A00';
  static const String brandNavyHex = '#183B73';

  static const int brandOrangeValue = 0xFFFF6A00;
  static const int brandNavyValue = 0xFF183B73;

  static const String defaultCountryCode = '+91';
  static const String defaultCurrencyCode = 'INR';
  static const String defaultLocale = 'en_IN';

  static const Duration defaultConnectTimeout = Duration(seconds: 10);
  static const Duration defaultReceiveTimeout = Duration(seconds: 30);

  static const String secureStoragePrefix = 'iu_';
  static const String prefsPrefix = 'iu_';

  static const String hiveBoxApp = 'iu_app_box';
}
