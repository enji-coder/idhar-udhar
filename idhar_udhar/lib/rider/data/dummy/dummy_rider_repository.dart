import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recent_activity.dart';
import '../models/rider_announcement.dart';
import '../models/rider_bank_details.dart';
import '../models/rider_document.dart';
import '../models/rider_earnings.dart';
import '../models/rider_order.dart';
import '../models/rider_profile.dart';
import '../models/vehicle_info.dart';
import 'dummy_rider_data.dart';

/// Local dummy repository — swap implementation later for API clients.
class DummyRiderRepository {
  RiderProfile getProfile() => DummyRiderData.profile;

  VehicleInfo getVehicle() => DummyRiderData.vehicle;

  RiderBankDetails getBank() => DummyRiderData.bank;

  RiderDriverDetails getDriver() => DummyRiderData.driver;

  List<RiderDocument> getDocuments() =>
      List<RiderDocument>.from(DummyRiderData.documents);

  List<RiderDocument> getRegistrationDocuments() =>
      List<RiderDocument>.from(DummyRiderData.registrationDocuments);

  List<RiderAnnouncement> getAnnouncements() =>
      List<RiderAnnouncement>.from(DummyRiderData.announcements);

  RiderOrder getIncomingOrder() => DummyRiderData.incomingOrder;

  RiderEarnings getEarnings() => DummyRiderData.earnings;

  double getWalletBalance() => DummyRiderData.walletBalance;

  List<RecentActivityItem> getRecentActivity() =>
      List<RecentActivityItem>.from(DummyRiderData.recentActivity);

  List<RecentActivityItem> getDeliveryHistory() =>
      List<RecentActivityItem>.from(DummyRiderData.deliveryHistory);

  List<VerificationStep> getVerificationSteps({required bool complete}) =>
      complete
          ? DummyRiderData.verificationComplete
          : DummyRiderData.verificationInProgress;

  bool validateOtp(String otp) =>
      otp.replaceAll(RegExp(r'\D'), '') == DummyRiderData.otp;

  Future<void> simulateLatency({
    Duration delay = const Duration(milliseconds: 450),
  }) =>
      Future<void>.delayed(delay);
}

final dummyRiderRepositoryProvider = Provider<DummyRiderRepository>(
  (ref) => DummyRiderRepository(),
);

final riderOnlineProvider = StateProvider<bool>((ref) => false);

final riderWalletBalanceProvider =
    StateProvider<double>((ref) => DummyRiderData.walletBalance);

final riderVehicleProvider =
    StateProvider<VehicleInfo>((ref) => DummyRiderData.vehicle);

final riderBankProvider =
    StateProvider<RiderBankDetails>((ref) => DummyRiderData.bank);

final riderProfileStateProvider =
    StateProvider<RiderProfile>((ref) => DummyRiderData.profile);

final riderDriverProvider =
    StateProvider<RiderDriverDetails>((ref) => DummyRiderData.driver);

final riderDocumentsProvider = StateProvider<List<RiderDocument>>(
  (ref) => List<RiderDocument>.from(DummyRiderData.documents),
);

final riderDeliveryHistoryProvider = StateProvider<List<RecentActivityItem>>(
  (ref) => List<RecentActivityItem>.from(DummyRiderData.deliveryHistory),
);

final deliveryStatusProvider =
    StateProvider<DeliveryLifecycleStatus>((ref) => DeliveryLifecycleStatus.accepted);

final activeOrderProvider = StateProvider<RiderOrder?>((ref) => null);
