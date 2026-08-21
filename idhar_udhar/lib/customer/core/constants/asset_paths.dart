/// Central asset path constants for IDHAR UDHAR.
///
/// Prefer these constants over string literals in widgets.
/// Optional / future paths may still be missing on disk — loaders should
/// keep graceful fallbacks (`SafeAssetImage`).
abstract final class AssetPaths {
  // ---------------------------------------------------------------------------
  // Folder roots
  // ---------------------------------------------------------------------------

  static const String logos = 'assets/customer/logos/';
  static const String icons = 'assets/customer/icons/';
  static const String illustrations = 'assets/customer/illustrations/';
  static const String images = 'assets/customer/images/';
  static const String images3d = 'assets/customer/images/3d/';
  static const String lottie = 'assets/customer/lottie/';
  static const String fonts = 'assets/customer/fonts/';
  static const String animations = 'assets/customer/animations/';

  // ---------------------------------------------------------------------------
  // Logos (present)
  // ---------------------------------------------------------------------------

  /// Official brand mark + wordmark PNG — single source of truth.
  /// Prefer [TopLogo] with `showWordmark: false` (PNG already includes text).
  static const String logo = 'assets/customer/logos/idhar_udhar_logo.png';

  /// Optional vector mark (add later; keep PNG as primary).
  static const String logoSvg = 'assets/customer/logos/idhar_udhar_logo.svg';

  // ---------------------------------------------------------------------------
  // Background images
  // ---------------------------------------------------------------------------

  /// Full-bleed auth / login / OTP photographic background.
  static const String authBackground =
      'assets/customer/images/auth_sunset_background.webp';

  /// Login-screen hero background (sunset logistics illustration).
  static const String loginBackground = 'assets/customer/images/login_background.png';

  /// Optional splash cinematic background (falls back to sunset gradient).
  static const String splashBackground = 'assets/customer/images/splash_background.webp';

  /// Design-reference splash artwork (full-bleed).
  static const String splashScreen = 'assets/customer/images/splash_screen.png';

  /// Premium delivery truck for splash (illustrations folder).
  static const String splashDeliveryTruck =
      'assets/customer/illustrations/splash/splash_delivery_truck.png';

  /// Compact truck visual for the login hero.
  static const String loginDeliveryTruck =
      'assets/customer/illustrations/login/login_delivery_truck.png';

  // ---------------------------------------------------------------------------
  // Official 3D asset family (assets/customer/images/3d/) — shipped
  // ---------------------------------------------------------------------------

  /// Branded box delivery truck.
  static const String truck =
      'assets/customer/images/3d/idhar_udhar_delivery_truck.png';

  /// Delivery bike / scooter with cargo box.
  static const String bike =
      'assets/customer/images/3d/idhar_udhar_delivery_bike.png';

  /// Auto-rickshaw / three-wheeler delivery vehicle.
  static const String auto =
      'assets/customer/images/3d/idhar_udhar_auto_rickshaw.png';

  /// Compact branded hatchback.
  static const String car = 'assets/customer/images/3d/idhar_udhar_car.png';

  /// Small flatbed / pickup logistics truck.
  static const String pickupTruck =
      'assets/customer/images/3d/idhar_udhar_pickup_truck.png';

  /// Single branded parcel box.
  static const String parcel = 'assets/customer/images/3d/idhar_udhar_parcel.png';

  /// Stack of branded parcels.
  static const String parcelStack =
      'assets/customer/images/3d/idhar_udhar_parcel_stack.png';

  /// Standing delivery rider character.
  static const String rider =
      'assets/customer/images/3d/idhar_udhar_rider-removebg.png';

  /// Location / map pin (navy + orange).
  static const String locationPin =
      'assets/customer/images/3d/idhar_udhar_location_pin.png';

  /// Invite / refer illustration (parcels + share network).
  static const String invite = 'assets/customer/images/3d/idhar_udhar_invite.png';

  /// Searching-for-rider hero (rider + scooter + pins).
  static const String searchingRider =
      'assets/customer/images/3d/idhar_udhar_searching_rider.png';

  /// In-transit delivery progress (rider on scooter + route).
  static const String deliveryProgress =
      'assets/customer/images/3d/idhar_udhar_delivery_progress.png';

  /// Home-shifting / moving items composition.
  static const String movingItems =
      'assets/customer/images/3d/idhar_udhar_moving_items.png';

  // ---------------------------------------------------------------------------
  // Location illustrations (legacy / optional paths)
  // ---------------------------------------------------------------------------

  static const String locationIllustration =
      'assets/customer/illustrations/location_permission.webp';

  // ---------------------------------------------------------------------------
  // Vehicle illustrations (legacy placeholders — prefer 3D constants above)
  // ---------------------------------------------------------------------------

  static const String vehicleBike = bike;
  static const String vehiclePickup = pickupTruck;
  static const String vehicleMiniTruck = truck;

  // ---------------------------------------------------------------------------
  // Parcel-type illustrations (legacy / optional paths)
  // ---------------------------------------------------------------------------

  static const String parcelDocuments =
      'assets/customer/illustrations/parcel_documents.webp';
  static const String parcelSmall = parcel;
  static const String parcelLarge = parcelStack;
  static const String parcelFurniture =
      'assets/customer/illustrations/parcel_furniture.webp';
  static const String parcelHomeShifting = movingItems;

  // ---------------------------------------------------------------------------
  // UI icons (SVG preferred)
  // ---------------------------------------------------------------------------

  static const String iconBike = 'assets/customer/icons/ic_bike.svg';
  static const String iconPickup = 'assets/customer/icons/ic_pickup.svg';
  static const String iconMiniTruck = 'assets/customer/icons/ic_mini_truck.svg';
  static const String iconParcel = 'assets/customer/icons/ic_parcel.svg';
  static const String iconDocument = 'assets/customer/icons/ic_document.svg';
  static const String iconLocation = 'assets/customer/icons/ic_location.svg';
  static const String iconPhone = 'assets/customer/icons/ic_phone.svg';
  static const String iconShield = 'assets/customer/icons/ic_shield.svg';
  static const String iconTracking = 'assets/customer/icons/ic_tracking.svg';
  static const String iconSupport = 'assets/customer/icons/ic_support.svg';

  // ---------------------------------------------------------------------------
  // Lottie
  // ---------------------------------------------------------------------------

  static const String lottieSplashTruck = 'assets/customer/lottie/splash_truck.json';
  static const String lottieSuccessCheck = 'assets/customer/lottie/success_check.json';

  // ---------------------------------------------------------------------------
  // Custom fonts (register under pubspec `fonts:` when files are added)
  // ---------------------------------------------------------------------------

  static const String fontPoppinsRegular = 'assets/customer/fonts/Poppins-Regular.ttf';
  static const String fontPoppinsMedium = 'assets/customer/fonts/Poppins-Medium.ttf';
  static const String fontPoppinsSemiBold = 'assets/customer/fonts/Poppins-SemiBold.ttf';
  static const String fontPoppinsBold = 'assets/customer/fonts/Poppins-Bold.ttf';
}
