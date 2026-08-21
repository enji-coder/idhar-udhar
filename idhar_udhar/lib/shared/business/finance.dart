import 'cancellation.dart';
import 'fare_engine.dart';

/// Confirmed 85/15/50 model. Applied only to confirmed **Trip Fare**,
/// never to the discounted customer payable.
class PaymentSettings {
  const PaymentSettings({
    this.riderPercentage = 85,
    this.companyCommissionPercentage = 15,
    this.operationalCostPercentageOfCommission = 50,
    this.versionId = 'pay_v1',
  });

  final double riderPercentage;
  final double companyCommissionPercentage;
  final double operationalCostPercentageOfCommission;
  final String versionId;

  bool get isValid =>
      FareEngine.round2(riderPercentage + companyCommissionPercentage) == 100 &&
      riderPercentage >= 0 &&
      companyCommissionPercentage >= 0 &&
      operationalCostPercentageOfCommission >= 0 &&
      operationalCostPercentageOfCommission <= 100;
}

class TripFinanceSnapshot {
  const TripFinanceSnapshot({
    required this.rideAmount,
    required this.riderPercentage,
    required this.companyCommissionPercentage,
    required this.operationalCostPercentage,
    required this.riderAmount,
    required this.companyCommissionAmount,
    required this.operationalCostAmount,
    required this.actualProfitAmount,
    required this.settingsVersionId,
    required this.frozenAt,
    this.taxAmount = 0,
  });

  final double rideAmount;
  final double riderPercentage;
  final double companyCommissionPercentage;
  final double operationalCostPercentage;
  final double riderAmount;
  final double companyCommissionAmount;
  final double operationalCostAmount;
  final double actualProfitAmount;
  final String settingsVersionId;
  final DateTime frozenAt;
  final double taxAmount;

  TripFinanceSnapshot copy() => this;
}

abstract final class FinanceEngine {
  static const PaymentSettings defaults = PaymentSettings();

  /// 85/15 is always on [rideAmount] = confirmed Trip Fare.
  /// A ₹10 discount that makes the customer pay ₹90 does not change rider ₹85.
  static TripFinanceSnapshot freezeTrip({
    required double rideAmount,
    PaymentSettings settings = defaults,
    DateTime? frozenAt,
  }) {
    final double ride = FareEngine.round2(rideAmount);
    final double riderAmount =
        FareEngine.round2(ride * settings.riderPercentage / 100);
    final double commission = FareEngine.round2(ride - riderAmount);
    final double opex = FareEngine.round2(
      commission * settings.operationalCostPercentageOfCommission / 100,
    );
    return TripFinanceSnapshot(
      rideAmount: ride,
      riderPercentage: settings.riderPercentage,
      companyCommissionPercentage: settings.companyCommissionPercentage,
      operationalCostPercentage:
          settings.operationalCostPercentageOfCommission,
      riderAmount: riderAmount,
      companyCommissionAmount: commission,
      operationalCostAmount: opex,
      actualProfitAmount: FareEngine.round2(commission - opex),
      settingsVersionId: settings.versionId,
      frozenAt: frozenAt ?? DateTime.now(),
      taxAmount: 0,
    );
  }

  /// Cancelled orders: keep trip fare for display. Split follows the
  /// cancellation quote (not automatically 85/15). Fee ₹0 → zero split.
  static TripFinanceSnapshot freezeCancelled({
    required double rideAmount,
    PaymentSettings settings = defaults,
    CancellationQuote? cancellation,
    DateTime? frozenAt,
  }) {
    final double riderAmount = cancellation?.riderAmount ?? 0;
    final double companyAmount = cancellation?.companyAmount ?? 0;
    final double opex = FareEngine.round2(
      companyAmount * settings.operationalCostPercentageOfCommission / 100,
    );
    return TripFinanceSnapshot(
      rideAmount: FareEngine.round2(rideAmount),
      riderPercentage: cancellation?.riderSharePercent ?? 0,
      companyCommissionPercentage: cancellation?.companySharePercent ?? 100,
      operationalCostPercentage:
          settings.operationalCostPercentageOfCommission,
      riderAmount: riderAmount,
      companyCommissionAmount: companyAmount,
      operationalCostAmount: opex,
      actualProfitAmount: FareEngine.round2(companyAmount - opex),
      settingsVersionId: settings.versionId,
      frozenAt: frozenAt ?? DateTime.now(),
      taxAmount: 0,
    );
  }
}
