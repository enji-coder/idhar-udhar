import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import '../../constants/asset_paths.dart';
import 'mock_models.dart';

/// Central dummy catalog for customer UI demos.
abstract final class MockData {
  static const MockUser defaultUser = MockUser(
    id: 'u_demo',
    phone: '+919876543210',
    name: '',
  );

  static final List<MockLocation> locations = [
    const MockLocation(
      id: 'loc_home',
      label: 'Home',
      address: '12, Satellite Road, Ahmedabad',
      city: 'Ahmedabad',
      isSaved: true,
      iconName: 'home',
      landmark: 'Near ISRO',
      addressLabel: AddressLabel.home,
      latitude: 23.0225,
      longitude: 72.5714,
    ),
    const MockLocation(
      id: 'loc_office',
      label: 'Office',
      address: 'CG Road, Navrangpura, Ahmedabad',
      city: 'Ahmedabad',
      isSaved: true,
      iconName: 'work',
      landmark: 'Opposite SBI',
      addressLabel: AddressLabel.office,
      latitude: 23.0330,
      longitude: 72.5660,
    ),
    const MockLocation(
      id: 'loc_friend',
      label: 'Friend',
      address: 'Narol Industrial Area, Ahmedabad',
      city: 'Ahmedabad',
      isSaved: true,
      iconName: 'friend',
      landmark: 'Gate 2',
      addressLabel: AddressLabel.friend,
      latitude: 22.9800,
      longitude: 72.5900,
    ),
    const MockLocation(
      id: 'loc_other',
      label: 'Other',
      address: 'Vastrapur Lake, Ahmedabad',
      city: 'Ahmedabad',
      isSaved: true,
      iconName: 'place',
      landmark: 'Parking side',
      addressLabel: AddressLabel.other,
      latitude: 23.0380,
      longitude: 72.5290,
    ),
    const MockLocation(
      id: 'loc_current',
      label: 'Current Location',
      address: 'Navrangpura, Ahmedabad',
      city: 'Ahmedabad',
      iconName: 'my_location',
      latitude: 23.0350,
      longitude: 72.5600,
    ),
    const MockLocation(
      id: 'loc_vesu',
      label: 'Vesu',
      address: 'Vesu Main Road, Surat',
      city: 'Surat',
      iconName: 'place',
      latitude: 21.1418,
      longitude: 72.7709,
    ),
    const MockLocation(
      id: 'loc_sg',
      label: 'SG Highway',
      address: 'Near Rajpath Club, Ahmedabad',
      city: 'Ahmedabad',
      iconName: 'place',
      latitude: 23.0470,
      longitude: 72.5310,
    ),
    const MockLocation(
      id: 'loc_paldi',
      label: 'Paldi',
      address: 'Paldi Cross Road, Ahmedabad',
      city: 'Ahmedabad',
      iconName: 'place',
      latitude: 23.0115,
      longitude: 72.5650,
    ),
    const MockLocation(
      id: 'loc_bopal',
      label: 'Bopal',
      address: 'Bopal, Ahmedabad',
      city: 'Ahmedabad',
      iconName: 'place',
      latitude: 23.0300,
      longitude: 72.4720,
    ),
  ];

  static final List<MockVehicle> vehicles = [
    const MockVehicle(
      id: 'v_bike',
      type: VehicleType.bike,
      name: 'Bike',
      description: 'Documents & small parcels',
      capacity: 'Up to 20 kg',
      etaMinutes: 12,
      baseFare: 79,
      imagePath: AssetPaths.bike,
    ),
    const MockVehicle(
      id: 'v_scooty',
      type: VehicleType.scooty,
      name: 'Scooty',
      description: 'City drops & light parcels',
      capacity: 'Up to 20 kg',
      etaMinutes: 14,
      baseFare: 89,
      imagePath: AssetPaths.scooty,
    ),
    const MockVehicle(
      id: 'v_auto',
      type: VehicleType.auto,
      name: 'Three Wheeler',
      description: 'City drops & medium boxes',
      capacity: 'Up to 100 kg',
      etaMinutes: 15,
      baseFare: 149,
      imagePath: AssetPaths.auto,
    ),
    const MockVehicle(
      id: 'v_truck',
      type: VehicleType.truck,
      name: 'Truck',
      description: 'Full load & shifting',
      capacity: 'Up to 1000 kg',
      etaMinutes: 30,
      baseFare: 699,
      imagePath: AssetPaths.truck,
    ),
  ];

  /// Kept for assets / legacy references — not shown as primary home services.
  static final List<MockVehicle> legacyVehicles = [
    const MockVehicle(
      id: 'v_car',
      type: VehicleType.car,
      name: 'Car',
      description: 'Secure cabin deliveries',
      capacity: 'Up to 200 kg',
      etaMinutes: 18,
      baseFare: 249,
      imagePath: AssetPaths.car,
    ),
    const MockVehicle(
      id: 'v_pickup',
      type: VehicleType.pickup,
      name: 'Pickup',
      description: 'Furniture & bulk items',
      capacity: 'Up to 500 kg',
      etaMinutes: 22,
      baseFare: 399,
      imagePath: AssetPaths.pickupTruck,
    ),
  ];

  /// Artwork and home-tile family for a catalog row.
  ///
  /// Slug pairs win. An exact display name is used only when both slug fields
  /// are empty. Substrings such as "tempo" are not a vehicle identity.
  static ({ServiceFamily family, VehicleType type})? presentationFor({
    required String name,
    String? vehicleTypeCode,
    String? vehicleCode,
  }) {
    final String typeCode = (vehicleTypeCode ?? '').trim().toLowerCase();
    final String code = (vehicleCode ?? '').trim().toLowerCase();
    if (typeCode.isEmpty && code.isEmpty) {
      return _presentationForExactName(name);
    }
    if (typeCode.isEmpty || code.isEmpty) {
      return null;
    }
    return _presentationForSlug(typeCode, code);
  }

  static ({ServiceFamily family, VehicleType type})? _presentationForSlug(
    String typeCode,
    String code,
  ) {
    switch (code) {
      case 'bike':
        if (typeCode != 'two_wheeler') return null;
        return (family: ServiceFamily.twoWheeler, type: VehicleType.bike);
      case 'scooty':
        if (typeCode != 'two_wheeler') return null;
        return (family: ServiceFamily.twoWheeler, type: VehicleType.scooty);
      case 'loader_riksha':
        if (typeCode != 'three_wheeler') return null;
        return (family: ServiceFamily.threeWheeler, type: VehicleType.auto);
      case 'mini_truck':
      case 'tempo':
      case 'large_tempo':
        if (typeCode != 'truck') return null;
        return (family: ServiceFamily.truck, type: VehicleType.pickup);
      case 'truck':
        if (typeCode != 'truck') return null;
        return (family: ServiceFamily.truck, type: VehicleType.truck);
      default:
        return null;
    }
  }

  static ({ServiceFamily family, VehicleType type})? _presentationForExactName(
    String name,
  ) {
    switch (name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim()) {
      case 'bike':
        return (family: ServiceFamily.twoWheeler, type: VehicleType.bike);
      case 'scooty':
      case 'scooter':
        return (family: ServiceFamily.twoWheeler, type: VehicleType.scooty);
      case '3w tempo':
      case '3w auto':
      case 'loader riksha':
      case 'loader rickshaw':
      case 'loader rikshaw':
      case 'loading riksha':
        return (family: ServiceFamily.threeWheeler, type: VehicleType.auto);
      case 'chhota hathi / tata ace':
      case 'pickup':
      case 'mini truck':
      case 'tempo':
      case 'large tempo':
        return (family: ServiceFamily.truck, type: VehicleType.pickup);
      case 'tempo 407':
      case 'truck / eicher':
      case 'truck':
        return (family: ServiceFamily.truck, type: VehicleType.truck);
      default:
        return null;
    }
  }

  static String categoryNameOf(MockVehicle vehicle) {
    switch (vehicle.type) {
      case VehicleType.bike:
      case VehicleType.scooty:
        return 'Bike';
      case VehicleType.auto:
        return 'Auto';
      case VehicleType.pickup:
        return 'Mini Truck';
      case VehicleType.truck:
      case VehicleType.car:
        return 'Truck';
    }
  }

  static bool _categoryVisible(String name, List<VehicleCategory> catalog) {
    for (final row in catalog) {
      if (row.name.toLowerCase() == name.toLowerCase()) {
        return row.isActive && row.available;
      }
    }
    return false;
  }

  static String artworkForCategoryName(String? name) {
    final presented = presentationFor(name: name ?? '');
    if (presented == null) {
      return AssetPaths.parcel;
    }
    return artworkFor(presented.type);
  }

  static String artworkFor(VehicleType type) {
    switch (type) {
      case VehicleType.bike:
        return AssetPaths.bike;
      case VehicleType.scooty:
        return AssetPaths.scooty;
      case VehicleType.auto:
        return AssetPaths.auto;
      case VehicleType.car:
        return AssetPaths.car;
      case VehicleType.pickup:
        return AssetPaths.pickupTruck;
      case VehicleType.truck:
        return AssetPaths.truck;
    }
  }

  static MockVehicle _synthesized(VehicleCategory category) {
    final presented = presentationFor(
      vehicleTypeCode: category.vehicleTypeCode,
      vehicleCode: category.vehicleCode,
      name: category.name,
    );
    final VehicleType type = presented?.type ?? VehicleType.car;
    final bool isTwo =
        type == VehicleType.bike || type == VehicleType.scooty;
    final bool isAuto = type == VehicleType.auto;
    return MockVehicle(
      id: 'v_${category.id.toLowerCase()}',
      type: type,
      name: category.name,
      description: (category.size ?? '').trim().isEmpty
          ? 'Admin-managed vehicle type'
          : category.size!.trim(),
      capacity: (category.weightCapacity ?? '').trim().isEmpty
          ? (isTwo
              ? 'Up to 20 kg'
              : isAuto
                  ? 'Up to 100 kg'
                  : 'Up to 1000 kg')
          : category.weightCapacity!.trim(),
      etaMinutes: isTwo ? 12 : isAuto ? 15 : 28,
      baseFare: category.baseFare,
      perKm: category.perKm,
      serviceFamily: presented?.family,
      imagePath: presented == null ? AssetPaths.parcel : artworkFor(type),
    );
  }

  static List<MockVehicle> vehiclesForFamily(
    ServiceFamily? family, {
    List<VehicleCategory>? catalog,
  }) {
    final rows = catalog ?? const <VehicleCategory>[];
    final existing = <MockVehicle>[
      ...vehicles,
      ...legacyVehicles,
    ].where((vehicle) => _categoryVisible(categoryNameOf(vehicle), rows)).toList();

    final extras = rows
        .where((row) => row.isActive && row.available)
        .where((row) => !existing.any((vehicle) =>
            vehicle.name.toLowerCase() == row.name.toLowerCase() ||
            categoryNameOf(vehicle).toLowerCase() == row.name.toLowerCase()))
        .map(_synthesized)
        .toList();

    final List<MockVehicle> pool = [...existing, ...extras];
    if (family == null) {
      return [
        ...existing.where(vehicles.contains),
        ...extras,
      ];
    }
    bool matches(MockVehicle vehicle) {
      if (vehicle.serviceFamily != null) {
        return vehicle.serviceFamily == family;
      }
      switch (family) {
        case ServiceFamily.twoWheeler:
          return vehicle.type == VehicleType.bike ||
              vehicle.type == VehicleType.scooty;
        case ServiceFamily.threeWheeler:
          return vehicle.type == VehicleType.auto;
        case ServiceFamily.truck:
          return vehicle.type == VehicleType.truck ||
              vehicle.type == VehicleType.pickup ||
              (vehicle.type == VehicleType.car && vehicle.name == 'Car');
      }
    }

    return pool.where(matches).toList();
  }

  static bool isTwoWheeler(MockVehicle vehicle) {
    return vehicle.type == VehicleType.bike ||
        vehicle.type == VehicleType.scooty;
  }

  static final List<WalletPaymentOption> walletPaymentOptions = [
    const WalletPaymentOption(
      id: 'pay_gpay',
      kind: WalletPaymentMethodKind.googlePay,
      label: 'Google Pay',
      group: 'UPI',
    ),
    const WalletPaymentOption(
      id: 'pay_phonepe',
      kind: WalletPaymentMethodKind.phonePe,
      label: 'PhonePe',
      group: 'UPI',
    ),
    const WalletPaymentOption(
      id: 'pay_paytm',
      kind: WalletPaymentMethodKind.paytm,
      label: 'Paytm',
      group: 'UPI',
    ),
    const WalletPaymentOption(
      id: 'pay_nb',
      kind: WalletPaymentMethodKind.netBanking,
      label: 'Net Banking',
      group: 'Net Banking',
    ),
    const WalletPaymentOption(
      id: 'pay_cc',
      kind: WalletPaymentMethodKind.creditCard,
      label: 'Credit Card',
      group: 'Card',
    ),
    const WalletPaymentOption(
      id: 'pay_dc',
      kind: WalletPaymentMethodKind.debitCard,
      label: 'Debit Card',
      group: 'Card',
    ),
  ];

  static const MockRider demoRider = MockRider(
    id: 'r_01',
    name: 'Aarav Patel',
    vehicleLabel: 'Bike • GJ-01-AB-2345',
    rating: 4.8,
    phone: '+919800011122',
    trips: 842,
    imagePath: AssetPaths.rider,
  );

  static final List<MockParcelCategory> parcelCategories = [
    const MockParcelCategory(
      id: 'c_docs',
      label: 'Documents',
      imagePath: AssetPaths.parcel,
      icon: 'description',
    ),
    const MockParcelCategory(
      id: 'c_pkg',
      label: 'Package',
      imagePath: AssetPaths.parcelStack,
      icon: 'inventory_2',
    ),
    const MockParcelCategory(
      id: 'c_elec',
      label: 'Electronics',
      imagePath: AssetPaths.parcel,
      icon: 'devices',
    ),
    const MockParcelCategory(
      id: 'c_clothes',
      label: 'Clothes',
      imagePath: AssetPaths.parcel,
      icon: 'checkroom',
    ),
    const MockParcelCategory(
      id: 'c_food',
      label: 'Food',
      imagePath: AssetPaths.parcel,
      icon: 'restaurant',
    ),
    const MockParcelCategory(
      id: 'c_furn',
      label: 'Furniture',
      imagePath: AssetPaths.movingItems,
      icon: 'chair',
    ),
    const MockParcelCategory(
      id: 'c_gift',
      label: 'Gift',
      imagePath: AssetPaths.invite,
      icon: 'card_giftcard',
    ),
    const MockParcelCategory(
      id: 'c_other',
      label: 'Others',
      imagePath: AssetPaths.parcelStack,
      icon: 'more_horiz',
    ),
  ];

  static final List<MockParcelSize> parcelSizes = [
    const MockParcelSize(
      id: 's_sm',
      label: 'Small',
      subtitle: 'Up to 30 cm',
      imagePath: AssetPaths.parcel,
      maxCm: 30,
    ),
    const MockParcelSize(
      id: 's_md',
      label: 'Medium',
      subtitle: 'Up to 60 cm',
      imagePath: AssetPaths.parcel,
      maxCm: 60,
    ),
    const MockParcelSize(
      id: 's_lg',
      label: 'Large',
      subtitle: 'Up to 90 cm',
      imagePath: AssetPaths.parcelStack,
      maxCm: 90,
    ),
    const MockParcelSize(
      id: 's_xl',
      label: 'Extra Large',
      subtitle: 'Above 90 cm',
      imagePath: AssetPaths.movingItems,
    ),
  ];

  static List<MockOrder> seedOrders() {
    final MockVehicle bike = vehicles.first;
    final MockVehicle threeWheeler = vehicles
        .firstWhere((v) => v.type == VehicleType.auto, orElse: () => vehicles[2]);
    return [
      MockOrder(
        id: 'IU-2048',
        status: OrderStatus.inTransit,
        pickup: locations[4],
        drop: locations[5],
        vehicle: bike,
        fare: 149,
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
        rider: demoRider,
        packageLabel: 'Documents',
        weightKg: 2,
        etaMinutes: 18,
      ),
      MockOrder(
        id: 'IU-1980',
        status: OrderStatus.delivered,
        pickup: locations[0],
        drop: locations[1],
        vehicle: threeWheeler,
        fare: 249,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        rider: demoRider,
        packageLabel: 'Package',
        weightKg: 8,
        etaMinutes: 0,
      ),
      MockOrder(
        id: 'IU-1766',
        status: OrderStatus.cancelled,
        pickup: locations[1],
        drop: locations[6],
        vehicle: bike,
        fare: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
        packageLabel: 'Gift',
        weightKg: 3,
      ),
      MockOrder(
        id: 'IU-AMD-0000010500',
        status: OrderStatus.atCompanyOffice,
        pickup: locations[0],
        drop: locations[7],
        vehicle: bike,
        fare: 79,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        rider: demoRider,
        packageLabel: 'Parcel',
        weightKg: 4,
        etaMinutes: 0,
        failedReason: 'Receiver Unavailable',
        officeCompensation: 40,
        officeDistanceKm: 5,
        customerNotice:
            'Your delivery could not be completed because the receiver was unavailable. Your parcel has been safely moved to the IDHAR UDHAR company office. You can request a resend to the original destination.',
      ),
    ];
  }
}
