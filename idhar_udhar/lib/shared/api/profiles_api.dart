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
  });

  final String identityId;
  final String customerProfileId;
  final String? displayName;
  final String? email;
  final String? invoiceEmail;
  final String? status;
  final String? phoneNormalized;

  factory CustomerProfile.fromJson(Map<String, Object?> json) {
    return CustomerProfile(
      identityId: jsonString(json['identity_id']) ?? '',
      customerProfileId: jsonString(json['customer_profile_id']) ?? '',
      displayName: jsonString(json['display_name']),
      email: jsonString(json['email']),
      invoiceEmail: jsonString(json['invoice_email']),
      status: jsonString(json['status']),
      phoneNormalized: jsonString(json['phone_normalized']),
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

  Future<RiderApiProfile> rider() async {
    return RiderApiProfile.fromJson(await _client.get('/v1/rider/profile'));
  }
}
