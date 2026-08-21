import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/business/business.dart';

import 'dummy_rider_repository.dart';

final riderCodDueProvider = StateProvider<double>((ref) => 0);

final riderLastSettlementProvider = StateProvider<CodSettlement?>((ref) => null);

bool riderIsSuspended(WidgetRef ref) =>
    CodEngine.isSuspended(ref.read(riderCodDueProvider));

void applyRiderEarning(WidgetRef ref, double grossEarning) {
  final CodSettlement settlement = CodEngine.applyEarning(
    availableWallet: ref.read(riderWalletBalanceProvider),
    codDue: ref.read(riderCodDueProvider),
    grossEarning: grossEarning,
  );
  ref.read(riderWalletBalanceProvider.notifier).state =
      settlement.availableWallet;
  ref.read(riderCodDueProvider.notifier).state = settlement.codDue;
  ref.read(riderLastSettlementProvider.notifier).state = settlement;
}

void applyRiderRecharge(WidgetRef ref, double amount) {
  applyRiderEarning(ref, amount);
}

void applyCashCompanyDue(WidgetRef ref, double companyShare) {
  final CodLedger next = CodEngine.addCashCompanyDue(
    availableWallet: ref.read(riderWalletBalanceProvider),
    codDue: ref.read(riderCodDueProvider),
    companyShare: companyShare,
  );
  ref.read(riderWalletBalanceProvider.notifier).state = next.availableWallet;
  ref.read(riderCodDueProvider.notifier).state = next.codDue;
}

void completeRiderTrip(
  WidgetRef ref, {
  required double cashCollected,
  required double riderAmount,
}) {
  final double due = CodEngine.companyDueFromCash(
    cashCollected: cashCollected,
    riderEarning: riderAmount,
  );
  if (due > 0) {
    applyCashCompanyDue(ref, due);
  }
  final double fromPlatform = FareEngine.round2(riderAmount - cashCollected);
  if (fromPlatform > 0) {
    applyRiderEarning(ref, fromPlatform);
  }
}
