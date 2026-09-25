import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_location_service.dart';
import 'google_maps_http.dart';
import 'maps_platform.dart';
import 'places_service.dart';
import 'routes_service.dart';

final mapsPlatformProvider = Provider<MapsPlatform>((ref) => MapsPlatform());

final googleMapsHttpProvider = Provider<GoogleMapsHttp>((ref) {
  return GoogleMapsHttp(ref.watch(mapsPlatformProvider));
});

final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return DeviceLocationService(ref.watch(mapsPlatformProvider));
});

final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService(ref.watch(googleMapsHttpProvider));
});

final routesServiceProvider = Provider<RoutesService>((ref) {
  return RoutesService(ref.watch(googleMapsHttpProvider));
});
