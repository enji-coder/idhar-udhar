import 'fare_engine.dart';

/// COD Due is money the rider owes the company. It is never stored as a
/// negative wallet balance.
class CodLedger {
  const CodLedger({
    this.availableWallet = 0,
    this.codDue = 0,
  });

  final double availableWallet;
  final double codDue;

  bool get isSuspended => CodEngine.isSuspended(codDue);
}

class CodSettlement {
  const CodSettlement({
    required this.grossEarning,
    required this.settledAgainstCod,
    required this.availableCredit,
    required this.availableWallet,
    required this.codDue,
  });

  final double grossEarning;
  final double settledAgainstCod;
  final double availableCredit;
  final double availableWallet;
  final double codDue;
}

abstract final class CodEngine {
  static const double suspendThreshold = 100;

  static bool isSuspended(double codDue) =>
      FareEngine.round2(codDue) >= suspendThreshold;

  static double _floor0(double value) {
    final double rounded = FareEngine.round2(value);
    return rounded < 0 ? 0 : rounded;
  }

  /// Eligible earning (online trip, cancellation rider share, etc.) settles
  /// COD Due first. Remainder becomes available wallet. Never negative.
  static CodSettlement applyEarning({
    required double availableWallet,
    required double codDue,
    required double grossEarning,
  }) {
    final double gross = _floor0(grossEarning);
    final double due = _floor0(codDue);
    final double wallet = _floor0(availableWallet);
    final double settled = gross < due ? gross : due;
    final double remainingDue = _floor0(due - settled);
    final double credit = _floor0(gross - settled);
    return CodSettlement(
      grossEarning: gross,
      settledAgainstCod: settled,
      availableCredit: credit,
      availableWallet: _floor0(wallet + credit),
      codDue: remainingDue,
    );
  }

  /// Wallet recharge settles COD Due first. Remainder is available wallet.
  static CodSettlement applyRecharge({
    required double availableWallet,
    required double codDue,
    required double rechargeAmount,
  }) {
    return applyEarning(
      availableWallet: availableWallet,
      codDue: codDue,
      grossEarning: rechargeAmount,
    );
  }

  /// Cash trip: customer paid the rider. Company share becomes COD Due.
  /// Rider share is physical cash, not a digital wallet credit, and is not
  /// applied against this same trip's company share.
  static CodLedger addCashCompanyDue({
    required double availableWallet,
    required double codDue,
    required double companyShare,
  }) {
    return CodLedger(
      availableWallet: _floor0(availableWallet),
      codDue: _floor0(codDue + companyShare),
    );
  }

  /// Cash in the rider's hand beyond rider earning is COD Due.
  /// ₹100 cash + ₹85 earning → COD Due ₹15. Mixed cash below earning → ₹0.
  static double companyDueFromCash({
    required double cashCollected,
    required double riderEarning,
  }) {
    return _floor0(cashCollected - riderEarning);
  }
}
