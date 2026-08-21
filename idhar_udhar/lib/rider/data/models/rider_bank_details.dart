class RiderBankDetails {
  const RiderBankDetails({
    required this.bankName,
    required this.accountHolder,
    required this.accountNumber,
    required this.ifsc,
    required this.upiId,
    this.upiVerified = true,
    this.proofUploaded = false,
  });

  final String bankName;
  final String accountHolder;
  final String accountNumber;
  final String ifsc;
  final String upiId;
  final bool upiVerified;
  final bool proofUploaded;

  String get maskedAccount {
    final String n = accountNumber.replaceAll(RegExp(r'\s'), '');
    if (n.length <= 4) return 'XXXX';
    return 'XXXXXX${n.substring(n.length - 4)}';
  }

  String get upiStatus => upiVerified ? 'Verified' : 'Pending';

  String get proofStatus => proofUploaded ? 'Uploaded' : 'Missing';

  RiderBankDetails copyWith({
    String? bankName,
    String? accountHolder,
    String? accountNumber,
    String? ifsc,
    String? upiId,
    bool? upiVerified,
    bool? proofUploaded,
  }) {
    return RiderBankDetails(
      bankName: bankName ?? this.bankName,
      accountHolder: accountHolder ?? this.accountHolder,
      accountNumber: accountNumber ?? this.accountNumber,
      ifsc: ifsc ?? this.ifsc,
      upiId: upiId ?? this.upiId,
      upiVerified: upiVerified ?? this.upiVerified,
      proofUploaded: proofUploaded ?? this.proofUploaded,
    );
  }
}

class RiderDriverDetails {
  const RiderDriverDetails({
    required this.fullName,
    required this.mobile,
    required this.dateOfBirthLabel,
    required this.licenseNumber,
  });

  final String fullName;
  final String mobile;
  final String dateOfBirthLabel;
  final String licenseNumber;

  RiderDriverDetails copyWith({
    String? fullName,
    String? mobile,
    String? dateOfBirthLabel,
    String? licenseNumber,
  }) {
    return RiderDriverDetails(
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      dateOfBirthLabel: dateOfBirthLabel ?? this.dateOfBirthLabel,
      licenseNumber: licenseNumber ?? this.licenseNumber,
    );
  }
}
