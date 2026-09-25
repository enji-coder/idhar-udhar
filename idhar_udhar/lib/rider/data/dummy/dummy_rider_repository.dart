import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rider_bank_details.dart';
import '../models/rider_document.dart';
import '../models/rider_earnings.dart';
import '../models/rider_order.dart';
import '../models/rider_profile.dart';
import '../models/vehicle_info.dart';

/// Local dummy repository — swap implementation later for API clients.
class DummyRiderRepository {
  RiderProfile getProfile() => RiderProfile.empty;

  VehicleInfo getVehicle() => VehicleInfo.empty;

  RiderBankDetails getBank() => RiderBankDetails.empty;

  RiderDriverDetails getDriver() => RiderDriverDetails.empty;

  List<RiderDocument> getDocuments() => _blankDocuments();

  List<RiderDocument> getRegistrationDocuments() => _blankDocuments();

  List<VerificationStep> getVerificationSteps({required bool complete}) {
    return const <VerificationStep>[
      VerificationStep(
        title: 'Waiting for review',
        state: VerificationStepState.active,
      ),
      VerificationStep(
        title: 'Account activation',
        state: VerificationStepState.pending,
      ),
    ];
  }

  Future<void> simulateLatency({
    Duration delay = const Duration(milliseconds: 450),
  }) =>
      Future<void>.delayed(delay);
}

final dummyRiderRepositoryProvider = Provider<DummyRiderRepository>(
  (ref) => DummyRiderRepository(),
);

final riderOnlineProvider = StateProvider<bool>((ref) => false);

final riderWalletBalanceProvider = StateProvider<double>((ref) => 0);

final riderVehicleProvider =
    StateProvider<VehicleInfo>((ref) => VehicleInfo.empty);

final riderBankProvider =
    StateProvider<RiderBankDetails>((ref) => RiderBankDetails.empty);

final riderProfileStateProvider =
    StateProvider<RiderProfile>((ref) => RiderProfile.empty);

final riderDriverProvider =
    StateProvider<RiderDriverDetails>((ref) => RiderDriverDetails.empty);

List<RiderDocument> _blankDocuments() => <RiderDocument>[
      for (final RiderDocumentKind kind in RiderDocumentKind.values)
        RiderDocument(
          kind: kind,
          status: RiderDocumentStatus.uploadRequired,
        ),
    ];

final riderDocumentsProvider = StateProvider<List<RiderDocument>>(
  (ref) => _blankDocuments(),
);

final deliveryStatusProvider =
    StateProvider<DeliveryLifecycleStatus>((ref) => DeliveryLifecycleStatus.accepted);

final activeOrderProvider = StateProvider<RiderOrder?>((ref) => null);
