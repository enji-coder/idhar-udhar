import 'package:dio/dio.dart';

import 'api_client.dart';
import 'json_codec.dart';

class CustomerProfile {
  const CustomerProfile({
    required this.identityId,
    required this.customerProfileId,
    this.displayName,
    this.email,
    this.invoiceEmail,
    this.status,
    this.phoneNormalized,
    this.needsProfileSetup = false,
  });

  final String identityId;
  final String customerProfileId;
  final String? displayName;
  final String? email;
  final String? invoiceEmail;
  final String? status;
  final String? phoneNormalized;
  final bool needsProfileSetup;

  factory CustomerProfile.fromJson(Map<String, Object?> json) {
    final String displayName = jsonString(json['display_name']) ?? '';
    final bool flagged = json['needs_profile_setup'] == true;
    return CustomerProfile(
      identityId: jsonString(json['identity_id']) ?? '',
      customerProfileId: jsonString(json['customer_profile_id']) ?? '',
      displayName: displayName.isEmpty ? null : displayName,
      email: jsonString(json['email']),
      invoiceEmail: jsonString(json['invoice_email']),
      status: jsonString(json['status']),
      phoneNormalized: jsonString(json['phone_normalized']),
      needsProfileSetup: flagged || displayName.isEmpty || displayName == 'Customer',
    );
  }
}

class RiderApiVehicle {
  const RiderApiVehicle({
    required this.vehicleId,
    required this.vehicleCategoryId,
    required this.vehicleCategoryName,
    this.registration,
    this.model,
    this.color,
    this.manufacturingYear,
  });

  final String vehicleId;
  final String vehicleCategoryId;
  final String vehicleCategoryName;
  final String? registration;
  final String? model;
  final String? color;
  final int? manufacturingYear;

  factory RiderApiVehicle.fromJson(Map<String, Object?> json) {
    final year = json['manufacturing_year'];
    return RiderApiVehicle(
      vehicleId: jsonString(json['vehicle_id']) ?? '',
      vehicleCategoryId: jsonString(json['vehicle_category_id']) ?? '',
      vehicleCategoryName: jsonString(json['vehicle_category_name']) ?? '',
      registration: jsonString(json['registration']),
      model: jsonString(json['model']),
      color: jsonString(json['color']),
      manufacturingYear: year is num ? year.toInt() : int.tryParse('$year'),
    );
  }
}

class RiderApiProfile {
  const RiderApiProfile({
    required this.identityId,
    required this.riderProfileId,
    this.onboardingKycStatus,
    this.approvalStatus,
    this.onlineStatus,
    this.codOperationalStatus,
    this.phoneNormalized,
    this.email,
    this.name,
    this.dateOfBirth,
    this.preferredLanguage,
    this.hasProfilePicture = false,
    this.drivingLicence,
    this.vehicle,
    this.profileComplete = false,
    this.missingFields = const <String>[],
  });

  final String identityId;
  final String riderProfileId;
  final String? onboardingKycStatus;
  final String? approvalStatus;
  final String? onlineStatus;
  final String? codOperationalStatus;
  final String? phoneNormalized;
  final String? email;
  final String? name;
  final DateTime? dateOfBirth;
  final String? preferredLanguage;
  final bool hasProfilePicture;
  final String? drivingLicence;
  final RiderApiVehicle? vehicle;
  final bool profileComplete;
  final List<String> missingFields;

  factory RiderApiProfile.fromJson(Map<String, Object?> json) {
    final vehicleRaw = json['vehicle'];
    final missingRaw = json['missing_fields'];
    return RiderApiProfile(
      identityId: jsonString(json['identity_id']) ?? '',
      riderProfileId: jsonString(json['rider_profile_id']) ?? '',
      onboardingKycStatus: jsonString(json['onboarding_kyc_status']),
      approvalStatus: jsonString(json['approval_status']),
      onlineStatus: jsonString(json['online_status']),
      codOperationalStatus: jsonString(json['cod_operational_status']),
      phoneNormalized: jsonString(json['phone_normalized']),
      email: jsonString(json['email']),
      name: jsonString(json['name']),
      dateOfBirth: jsonDate(json['date_of_birth']),
      preferredLanguage: jsonString(json['preferred_language']),
      hasProfilePicture: json['has_profile_picture'] == true,
      drivingLicence: jsonString(json['driving_licence']),
      vehicle: vehicleRaw is Map
          ? RiderApiVehicle.fromJson(Map<String, Object?>.from(vehicleRaw))
          : null,
      profileComplete: json['profile_complete'] == true,
      missingFields: missingRaw is List
          ? missingRaw.map((item) => '$item').toList(growable: false)
          : const <String>[],
    );
  }
}

class RiderProfilePicture {
  const RiderProfilePicture({
    required this.downloadUrl,
    this.expiresIn,
  });

  final String downloadUrl;
  final int? expiresIn;

  factory RiderProfilePicture.fromJson(Map<String, Object?> json) {
    return RiderProfilePicture(
      downloadUrl: jsonString(json['download_url']) ?? '',
      expiresIn: json['download_url_expires_in'] is num
          ? (json['download_url_expires_in'] as num).toInt()
          : null,
    );
  }
}

class ProfilesApi {
  ProfilesApi(this._client);

  final ApiClient _client;

  Future<CustomerProfile> customer() async {
    return CustomerProfile.fromJson(await _client.get('/v1/customer/profile'));
  }

  Future<CustomerProfile> updateCustomer({
    required String displayName,
    String? email,
  }) async {
    return CustomerProfile.fromJson(
      await _client.put(
        '/v1/customer/profile',
        data: <String, Object?>{
          'display_name': displayName.trim(),
          if (email != null) 'email': email.trim(),
        },
      ),
    );
  }

  Future<RiderApiProfile> rider() async {
    return RiderApiProfile.fromJson(await _client.get('/v1/rider/profile'));
  }

  Future<RiderApiProfile> updateRider({
    String? name,
    String? email,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? preferredLanguage,
    String? drivingLicence,
  }) async {
    // Prefer PUT: some production proxies/ALB rules reject PATCH with 404.
    return RiderApiProfile.fromJson(
      await _client.put(
        '/v1/rider/profile',
        data: <String, Object?>{
          if (name != null) 'name': name.trim(),
          if (email != null) 'email': email.trim(),
          if (clearDateOfBirth) 'date_of_birth': null,
          if (dateOfBirth != null)
            'date_of_birth':
                '${dateOfBirth.year.toString().padLeft(4, '0')}-${dateOfBirth.month.toString().padLeft(2, '0')}-${dateOfBirth.day.toString().padLeft(2, '0')}',
          if (preferredLanguage != null)
            'preferred_language': preferredLanguage,
          if (drivingLicence != null) 'driving_licence': drivingLicence.trim(),
        },
      ),
    );
  }

  Future<RiderApiProfile> saveRiderVehicle({
    required String vehicleCategoryId,
    required String registration,
    required String model,
    required String color,
    required int manufacturingYear,
  }) async {
    return RiderApiProfile.fromJson(
      await _client.put(
        '/v1/rider/vehicle',
        data: <String, Object?>{
          'vehicle_category_id': vehicleCategoryId,
          'registration': registration.trim(),
          'model': model.trim(),
          'color': color.trim(),
          'manufacturing_year': manufacturingYear,
        },
      ),
    );
  }

  Future<RiderOnlineDay> riderOnlineTime({String? date}) async {
    final Map<String, Object?> body = await _client.get(
      '/v1/rider/online-time',
      query: date == null || date.isEmpty
          ? null
          : <String, dynamic>{'date': date},
    );
    return RiderOnlineDay.fromJson(body);
  }

  Future<RiderApiProfile> setRiderAvailability({required bool online}) async {
    final Map<String, Object?> body = await _client.post(
      '/v1/rider/availability',
      data: <String, Object?>{'online': online},
    );
    return RiderApiProfile(
      identityId: '',
      riderProfileId: '',
      approvalStatus: jsonString(body['approval_status']),
      onlineStatus: jsonString(body['online_status']),
    );
  }

  Future<void> setRiderLanguage(String preferredLanguage) async {
    await _client.put(
      '/v1/rider/profile/language',
      data: <String, Object?>{'preferred_language': preferredLanguage},
    );
  }

  Future<RiderProfilePicture?> riderProfilePicture() async {
    try {
      return RiderProfilePicture.fromJson(
        await _client.get('/v1/rider/profile/picture'),
      );
    } on Object {
      return null;
    }
  }

  Future<RiderProfilePicture> uploadRiderProfilePicture(String filePath) async {
    final FormData form = FormData.fromMap(<String, Object?>{
      'file': await MultipartFile.fromFile(filePath),
    });
    return RiderProfilePicture.fromJson(
      await _client.postForm(
        '/v1/rider/profile/picture',
        data: form,
        sendTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
      ),
    );
  }
}

class RiderOnlineShift {
  const RiderOnlineShift({
    required this.sessionId,
    required this.startedAt,
    required this.endedAt,
    required this.seconds,
    required this.active,
  });

  final String sessionId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int seconds;
  final bool active;

  factory RiderOnlineShift.fromJson(Map<String, Object?> json) {
    return RiderOnlineShift(
      sessionId: jsonString(json['session_id']) ?? '',
      startedAt: DateTime.tryParse(jsonString(json['started_at']) ?? ''),
      endedAt: DateTime.tryParse(jsonString(json['ended_at']) ?? ''),
      seconds: jsonInt(json['seconds']),
      active: jsonBool(json['active']),
    );
  }
}

class RiderOnlineDay {
  const RiderOnlineDay({
    required this.date,
    required this.timeZone,
    required this.totalSeconds,
    required this.activeElapsedSeconds,
    required this.activeStartedAt,
    required this.shifts,
  });

  final String date;
  final String timeZone;
  final int totalSeconds;
  final int? activeElapsedSeconds;
  final DateTime? activeStartedAt;
  final List<RiderOnlineShift> shifts;

  bool get hasActiveShift => activeElapsedSeconds != null;

  factory RiderOnlineDay.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> active = json['active'] is Map
        ? jsonObject(json['active'])
        : const <String, Object?>{};
    return RiderOnlineDay(
      date: jsonString(json['date']) ?? '',
      timeZone: jsonString(json['time_zone']) ?? 'Asia/Kolkata',
      totalSeconds: jsonInt(json['total_seconds']),
      activeElapsedSeconds:
          json['active'] == null ? null : jsonInt(active['elapsed_seconds']),
      activeStartedAt: DateTime.tryParse(
        jsonString(active['started_at']) ?? '',
      ),
      shifts: jsonList(json['shifts'])
          .map(jsonObject)
          .map(RiderOnlineShift.fromJson)
          .toList(growable: false),
    );
  }
}

String formatOnlineSeconds(int seconds) {
  final int safe = seconds < 0 ? 0 : seconds;
  final int hours = safe ~/ 3600;
  final int minutes = (safe % 3600) ~/ 60;
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  if (minutes > 0) {
    return '${minutes}m';
  }
  if (safe == 0) {
    return '0m';
  }
  return '${safe}s';
}
