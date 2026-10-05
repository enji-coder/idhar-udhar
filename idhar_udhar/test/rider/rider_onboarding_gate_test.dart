import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/routing/rider_routes.dart';
import 'package:idhar_udhar/rider/state/rider_onboarding.dart';

void main() {
  test('a completed rider is allowed onto Home', () {
    expect(
      riderHomeBlockRoute(
        profileReady: true,
        profileComplete: true,
        missingFields: const <String>[],
      ),
      isNull,
    );
  });

  test('a failed profile fetch does not open Home', () {
    expect(
      riderHomeBlockRoute(
        profileReady: false,
        profileComplete: false,
        missingFields: const <String>[],
      ),
      RiderRoutes.profileSetup,
    );
  });

  test('missing profile fields go to profile setup', () {
    expect(
      riderHomeBlockRoute(
        profileReady: true,
        profileComplete: false,
        missingFields: const <String>['email', 'vehicle_category'],
      ),
      RiderRoutes.profileSetup,
    );
  });

  test('missing vehicle fields go to vehicle selection', () {
    expect(
      riderHomeBlockRoute(
        profileReady: true,
        profileComplete: false,
        missingFields: const <String>['vehicle_category', 'vehicle_year'],
      ),
      RiderRoutes.vehicleType,
    );
  });

  test('a missing licence goes to driver details', () {
    expect(
      riderHomeBlockRoute(
        profileReady: true,
        profileComplete: false,
        missingFields: const <String>['driving_licence'],
      ),
      RiderRoutes.driverDetails,
    );
  });
}
