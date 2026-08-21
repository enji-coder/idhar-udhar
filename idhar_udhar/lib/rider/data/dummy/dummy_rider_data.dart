import '../models/recent_activity.dart';
import '../models/rider_announcement.dart';
import '../models/rider_bank_details.dart';
import '../models/rider_document.dart';
import '../models/rider_earnings.dart';
import '../models/rider_order.dart';
import '../models/rider_profile.dart';
import '../models/vehicle_info.dart';

/// Centralized dummy constants for Rider demo journey.
abstract final class DummyRiderData {
  static const String otp = '123456';
  static const String defaultMobile = '+91 98765 43210';
  static const String defaultMobileDigits = '9876543210';

  static final RiderProfile profile = RiderProfile(
    id: 'rider_demo_001',
    name: 'Rahul Sharma',
    mobile: defaultMobile,
    email: 'rahul.sharma@gmail.com',
    dateOfBirth: DateTime(1997, 8, 12),
    language: 'English',
    rating: 4.8,
  );

  static const VehicleInfo vehicle = VehicleInfo(
    type: RiderVehicleType.bike,
    number: 'GJ 05 AB 1234',
    model: 'Honda Shine',
    color: 'Black',
    manufacturingYear: 2023,
  );

  static const RiderBankDetails bank = RiderBankDetails(
    bankName: 'HDFC Bank',
    accountHolder: 'Rahul Sharma',
    accountNumber: '5010001233210',
    ifsc: 'HDFC0001234',
    upiId: 'rahul.sharma@okhdfc',
    upiVerified: true,
    proofUploaded: true,
  );

  static const RiderDriverDetails driver = RiderDriverDetails(
    fullName: 'Rahul Sharma',
    mobile: defaultMobile,
    dateOfBirthLabel: '12 Aug 1997',
    licenseNumber: 'GJ05 20190012345',
  );

  static const double walletBalance = 2450;

  static const List<RiderDocument> registrationDocuments = <RiderDocument>[
    RiderDocument(
      kind: RiderDocumentKind.aadhaarFront,
      status: RiderDocumentStatus.uploadRequired,
    ),
    RiderDocument(
      kind: RiderDocumentKind.aadhaarBack,
      status: RiderDocumentStatus.uploadRequired,
    ),
    RiderDocument(
      kind: RiderDocumentKind.panFront,
      status: RiderDocumentStatus.uploadRequired,
    ),
    RiderDocument(
      kind: RiderDocumentKind.drivingLicenseFront,
      status: RiderDocumentStatus.uploadRequired,
    ),
    RiderDocument(
      kind: RiderDocumentKind.drivingLicenseBack,
      status: RiderDocumentStatus.uploadRequired,
    ),
    RiderDocument(
      kind: RiderDocumentKind.vehicleRcFront,
      status: RiderDocumentStatus.uploadRequired,
    ),
    RiderDocument(
      kind: RiderDocumentKind.vehicleRcBack,
      status: RiderDocumentStatus.uploadRequired,
    ),
    RiderDocument(
      kind: RiderDocumentKind.bankProof,
      status: RiderDocumentStatus.uploadRequired,
    ),
  ];

  static const List<RiderDocument> documents = <RiderDocument>[
    RiderDocument(
      kind: RiderDocumentKind.aadhaarFront,
      status: RiderDocumentStatus.verified,
      fileName: 'aadhaar_front.jpg',
    ),
    RiderDocument(
      kind: RiderDocumentKind.aadhaarBack,
      status: RiderDocumentStatus.verified,
      fileName: 'aadhaar_back.jpg',
    ),
    RiderDocument(
      kind: RiderDocumentKind.panFront,
      status: RiderDocumentStatus.verified,
      fileName: 'pan_front.jpg',
    ),
    RiderDocument(
      kind: RiderDocumentKind.drivingLicenseFront,
      status: RiderDocumentStatus.verified,
      fileName: 'dl_front.jpg',
    ),
    RiderDocument(
      kind: RiderDocumentKind.drivingLicenseBack,
      status: RiderDocumentStatus.verified,
      fileName: 'dl_back.jpg',
    ),
    RiderDocument(
      kind: RiderDocumentKind.vehicleRcFront,
      status: RiderDocumentStatus.pendingVerification,
      fileName: 'rc_front.jpg',
    ),
    RiderDocument(
      kind: RiderDocumentKind.vehicleRcBack,
      status: RiderDocumentStatus.pendingVerification,
      fileName: 'rc_back.jpg',
    ),
    RiderDocument(
      kind: RiderDocumentKind.bankProof,
      status: RiderDocumentStatus.verified,
      fileName: 'passbook_front.jpg',
    ),
  ];

  static const List<RiderAnnouncement> announcements = <RiderAnnouncement>[
    RiderAnnouncement(
      kind: RiderAnnouncementKind.weekend,
      title: 'Weekend Incentive',
      body:
          'Complete eligible deliveries this weekend and unlock additional earnings.',
      badge: 'NEW',
      dateLabel: 'This weekend',
    ),
    RiderAnnouncement(
      kind: RiderAnnouncementKind.referral,
      title: 'Refer & Earn',
      body: 'Refer a new rider and earn a referral bonus.',
      badge: 'BONUS',
      dateLabel: 'Ongoing',
    ),
    RiderAnnouncement(
      kind: RiderAnnouncementKind.incentive,
      title: 'Peak Hour Bonus',
      body: 'Earn extra incentives during selected peak delivery hours.',
      badge: 'INCENTIVE',
      dateLabel: 'Weekdays 7–10 PM',
    ),
  ];

  static const List<VerificationStep> verificationInProgress =
      <VerificationStep>[
    VerificationStep(
      title: 'Profile Completed',
      state: VerificationStepState.done,
    ),
    VerificationStep(
      title: 'Documents Uploaded',
      state: VerificationStepState.done,
    ),
    VerificationStep(
      title: 'Background Verification',
      state: VerificationStepState.active,
    ),
    VerificationStep(
      title: 'Account Activation',
      state: VerificationStepState.pending,
    ),
  ];

  static const List<VerificationStep> verificationComplete =
      <VerificationStep>[
    VerificationStep(
      title: 'Profile Completed',
      state: VerificationStepState.done,
    ),
    VerificationStep(
      title: 'Documents Uploaded',
      state: VerificationStepState.done,
    ),
    VerificationStep(
      title: 'Background Verification',
      state: VerificationStepState.done,
    ),
    VerificationStep(
      title: 'Account Activation',
      state: VerificationStepState.done,
    ),
  ];

  static const RiderOrder incomingOrder = RiderOrder(
    id: 'IU-AMD-0000010248',
    pickup: 'Ahmedabad One Mall',
    drop: 'Satellite, Ahmedabad',
    distanceKm: 7.8,
    estimatedEarnings: 186,
    estimatedMinutes: 24,
    paymentMethod: RiderOrderPaymentMethod.online,
    customerMaskedName: 'Priya K.',
    customerMaskedPhone: '+91 ******3210',
    decisionSeconds: 27,
    tripAmount: 219,
    riderAmount: 186,
    companyShare: 33,
    officeDistanceKm: 5,
    officeCompensation: 40,
    customerResponsibility: 150,
    receiverResponsibility: 69,
    customerOnline: 100,
    customerCash: 50,
    receiverCash: 69,
    paymentStatusLabel: 'UNPAID',
  );

  static const RiderEarnings earnings = RiderEarnings(
    todayAmount: 1840,
    yesterdayChangePercent: 12.5,
    completedOrders: 14,
    onlineDuration: Duration(hours: 6, minutes: 24),
    targetOrders: 14,
    targetOrdersGoal: 20,
    targetAmount: 2650,
    targetAmountGoal: 3500,
    incentiveProgress: 1860,
    incentiveGoal: 2500,
    recentEarnings: <RecentEarningItem>[
      RecentEarningItem(
        label: 'Order #IU-AMD-0000010248',
        amount: 186,
        timeLabel: 'Completed',
      ),
      RecentEarningItem(
        label: 'Order #IU10247',
        amount: 142,
        timeLabel: 'Completed',
      ),
      RecentEarningItem(
        label: 'Order #IU10246',
        amount: 215,
        timeLabel: 'Completed',
      ),
    ],
  );

  static const List<RecentActivityItem> recentActivity = <RecentActivityItem>[
    RecentActivityItem(
      orderId: 'IU10248',
      pickup: 'Ahmedabad One Mall',
      drop: 'Satellite',
      amount: 186,
    ),
    RecentActivityItem(
      orderId: 'IU10247',
      pickup: 'Navrangpura',
      drop: 'Paldi',
      amount: 142,
    ),
    RecentActivityItem(
      orderId: 'IU10246',
      pickup: 'SG Highway',
      drop: 'Bodakdev',
      amount: 215,
    ),
  ];

  static const List<RecentActivityItem> deliveryHistory = <RecentActivityItem>[
    RecentActivityItem(
      orderId: 'IU10248',
      pickup: 'Ahmedabad One Mall',
      drop: 'Satellite',
      amount: 186,
      status: 'Accepted',
      timeLabel: '14 Aug, 6:20 PM',
    ),
    RecentActivityItem(
      orderId: 'IU10247',
      pickup: 'Navrangpura',
      drop: 'Paldi',
      amount: 142,
      status: 'Rejected by Rider',
      timeLabel: '14 Aug, 5:10 PM',
    ),
    RecentActivityItem(
      orderId: 'IU10245',
      pickup: 'Maninagar',
      drop: 'Vastral',
      amount: 168,
      status: 'Rejected by Client',
      timeLabel: '13 Aug, 8:40 PM',
    ),
    RecentActivityItem(
      orderId: 'IU10244',
      pickup: 'CG Road',
      drop: 'Navrangpura',
      amount: 95,
      status: 'Cancelled',
      timeLabel: '13 Aug, 2:15 PM',
    ),
    RecentActivityItem(
      orderId: 'IU10246',
      pickup: 'SG Highway',
      drop: 'Bodakdev',
      amount: 215,
      status: 'Completed',
      timeLabel: '12 Aug, 7:05 PM',
    ),
  ];

  static const List<String> welcomeBenefits = <String>[
    'Flexible working hours',
    'Fast and secure payments',
    '24/7 rider support',
  ];

  static const List<String> languages = <String>[
    'English',
    'Hindi',
    'Gujarati',
  ];
}
