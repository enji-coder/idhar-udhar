import 'package:flutter/material.dart';

/// Marker chosen from the accepted order's vehicle category name.
enum RiderVehicleMarker { bike, scooter, threeWheeler, truck, parcel }

RiderVehicleMarker vehicleMarkerFor(String vehicleName) {
  final String value = vehicleName.toLowerCase();
  if (value.contains('scooty') || value.contains('scooter')) {
    return RiderVehicleMarker.scooter;
  }
  if (value.contains('bike') ||
      value.contains('two wheeler') ||
      value.contains('two_wheeler')) {
    return RiderVehicleMarker.bike;
  }
  if (value.contains('truck') || value.contains('tata')) {
    return RiderVehicleMarker.truck;
  }
  if (value.contains('auto') ||
      value.contains('rickshaw') ||
      value.contains('three')) {
    return RiderVehicleMarker.threeWheeler;
  }
  return RiderVehicleMarker.parcel;
}

/// Existing project assets suitable as map markers (declared in pubspec).
///
/// Prefer square mid-size PNGs. Returns null when no dedicated asset exists
/// (caller should keep the default pin).
String? vehicleMapMarkerAssetPath(RiderVehicleMarker marker) {
  switch (marker) {
    case RiderVehicleMarker.bike:
      return 'assets/customer/images/3d/idhar_udhar_delivery_bike.png';
    case RiderVehicleMarker.scooter:
      return 'assets/rider/images/rider_delivery_scooter_3.png';
    case RiderVehicleMarker.truck:
      return 'assets/customer/images/3d/idhar_udhar_delivery_truck_1.png';
    case RiderVehicleMarker.threeWheeler:
    case RiderVehicleMarker.parcel:
      return null;
  }
}

IconData vehicleMarkerIcon(RiderVehicleMarker marker) {
  switch (marker) {
    case RiderVehicleMarker.bike:
    case RiderVehicleMarker.scooter:
      return Icons.two_wheeler_rounded;
    case RiderVehicleMarker.threeWheeler:
      return Icons.electric_rickshaw_rounded;
    case RiderVehicleMarker.truck:
      return Icons.local_shipping_rounded;
    case RiderVehicleMarker.parcel:
      return Icons.inventory_2_rounded;
  }
}

String vehicleMarkerLabel(RiderVehicleMarker marker, String vehicleName) {
  final String name = vehicleName.trim();
  if (name.isNotEmpty) {
    return name;
  }
  switch (marker) {
    case RiderVehicleMarker.bike:
      return 'Bike';
    case RiderVehicleMarker.scooter:
      return 'Scooter';
    case RiderVehicleMarker.threeWheeler:
      return 'Three wheeler';
    case RiderVehicleMarker.truck:
      return 'Truck';
    case RiderVehicleMarker.parcel:
      return 'Parcel';
  }
}
