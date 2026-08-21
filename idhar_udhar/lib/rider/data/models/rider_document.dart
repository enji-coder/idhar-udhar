enum RiderDocumentKind {
  aadhaarFront,
  aadhaarBack,
  panFront,
  drivingLicenseFront,
  drivingLicenseBack,
  vehicleRcFront,
  vehicleRcBack,
  bankProof,
}

enum RiderDocumentStatus {
  uploadRequired,
  uploaded,
  pendingVerification,
  verified,
}

extension RiderDocumentKindX on RiderDocumentKind {
  String get label {
    switch (this) {
      case RiderDocumentKind.aadhaarFront:
        return 'Aadhaar Front';
      case RiderDocumentKind.aadhaarBack:
        return 'Aadhaar Back';
      case RiderDocumentKind.panFront:
        return 'PAN Card';
      case RiderDocumentKind.drivingLicenseFront:
        return 'DL Front';
      case RiderDocumentKind.drivingLicenseBack:
        return 'DL Back';
      case RiderDocumentKind.vehicleRcFront:
        return 'RC Front';
      case RiderDocumentKind.vehicleRcBack:
        return 'RC Back';
      case RiderDocumentKind.bankProof:
        return 'Bank Proof';
    }
  }

  String get sectionTitle {
    switch (this) {
      case RiderDocumentKind.aadhaarFront:
      case RiderDocumentKind.aadhaarBack:
        return 'Aadhaar';
      case RiderDocumentKind.panFront:
        return 'PAN';
      case RiderDocumentKind.drivingLicenseFront:
      case RiderDocumentKind.drivingLicenseBack:
        return 'Driving License';
      case RiderDocumentKind.vehicleRcFront:
      case RiderDocumentKind.vehicleRcBack:
        return 'RC';
      case RiderDocumentKind.bankProof:
        return 'Bank Proof';
    }
  }

  String get description {
    switch (this) {
      case RiderDocumentKind.aadhaarFront:
        return 'Clear photo of Aadhaar front';
      case RiderDocumentKind.aadhaarBack:
        return 'Clear photo of Aadhaar back';
      case RiderDocumentKind.panFront:
        return 'PAN card front image';
      case RiderDocumentKind.drivingLicenseFront:
        return 'Driving license front';
      case RiderDocumentKind.drivingLicenseBack:
        return 'Driving license back';
      case RiderDocumentKind.vehicleRcFront:
        return 'Registration certificate front';
      case RiderDocumentKind.vehicleRcBack:
        return 'Registration certificate back';
      case RiderDocumentKind.bankProof:
        return 'Passbook front page or cancelled cheque';
    }
  }
}

extension RiderDocumentStatusX on RiderDocumentStatus {
  String get label {
    switch (this) {
      case RiderDocumentStatus.uploadRequired:
        return 'Missing';
      case RiderDocumentStatus.uploaded:
        return 'Selected';
      case RiderDocumentStatus.pendingVerification:
        return 'Pending Verification';
      case RiderDocumentStatus.verified:
        return 'Verified';
    }
  }
}

class RiderDocument {
  const RiderDocument({
    required this.kind,
    required this.status,
    this.fileName,
    this.localPath,
  });

  final RiderDocumentKind kind;
  final RiderDocumentStatus status;
  final String? fileName;
  final String? localPath;

  bool get isProvided => status != RiderDocumentStatus.uploadRequired;

  bool get canUpload =>
      status == RiderDocumentStatus.uploadRequired ||
      status == RiderDocumentStatus.uploaded ||
      status == RiderDocumentStatus.pendingVerification;

  bool get canView =>
      status != RiderDocumentStatus.uploadRequired && fileName != null;

  bool get isImage {
    final name = (fileName ?? localPath ?? '').toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  RiderDocument copyWith({
    RiderDocumentKind? kind,
    RiderDocumentStatus? status,
    String? fileName,
    String? localPath,
  }) {
    return RiderDocument(
      kind: kind ?? this.kind,
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
    );
  }
}
