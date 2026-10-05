import '../routing/rider_routes.dart';

/// Home is allowed only after the backend says required profile fields exist.
/// A failed profile fetch stays closed: it does not open Home.
String? riderHomeBlockRoute({
  required bool profileReady,
  required bool profileComplete,
  required List<String> missingFields,
}) {
  if (profileReady && profileComplete) return null;
  if (!profileReady) return RiderRoutes.profileSetup;
  const profileFields = <String>{'name', 'email', 'date_of_birth'};
  const vehicleFields = <String>{
    'vehicle_category',
    'vehicle_registration',
    'vehicle_model',
    'vehicle_color',
    'vehicle_year',
  };
  if (missingFields.any(profileFields.contains)) {
    return RiderRoutes.profileSetup;
  }
  if (missingFields.any(vehicleFields.contains)) {
    return RiderRoutes.vehicleType;
  }
  if (missingFields.contains('driving_licence')) {
    return RiderRoutes.driverDetails;
  }
  return RiderRoutes.profileSetup;
}
