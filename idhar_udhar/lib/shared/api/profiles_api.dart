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

class RiderApiProfile {
  const RiderApiProfile({
    required this.identityId,
    required this.riderProfileId,
    this.onboardingKycStatus,
    this.approvalStatus,
    this.onlineStatus,
    this.codOperationalStatus,
    this.phoneNormalized,
  });

  final String identityId;
  final String riderProfileId;
  final String? onboardingKycStatus;
  final String? approvalStatus;
  final String? onlineStatus;
  final String? codOperationalStatus;
  final String? phoneNormalized;

  factory RiderApiProfile.fromJson(Map<String, Object?> json) {
    return RiderApiProfile(
      identityId: jsonString(json['identity_id']) ?? '',
      riderProfileId: jsonString(json['rider_profile_id']) ?? '',
      onboardingKycStatus: jsonString(json['onboarding_kyc_status']),
      approvalStatus: jsonString(json['approval_status']),
      onlineStatus: jsonString(json['online_status']),
      codOperationalStatus: jsonString(json['cod_operational_status']),
      phoneNormalized: jsonString(json['phone_normalized']),
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
}
