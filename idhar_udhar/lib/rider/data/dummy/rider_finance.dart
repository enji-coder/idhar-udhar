import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/business/business.dart';

/// Display caches only. Never credit/debit here — wallet/COD are server-backed.
final riderCodDueProvider = StateProvider<double>((ref) => 0);

final riderOperationalStatusProvider = StateProvider<String>((ref) => 'CLEAR');

final riderRechargeToResumeProvider = StateProvider<double>((ref) => 0);

final riderWalletSuspendFloorProvider = StateProvider<double>((ref) => -100);

final riderLastSettlementProvider = StateProvider<CodSettlement?>((ref) => null);

bool riderIsSuspended(WidgetRef ref) {
  final String status = ref.read(riderOperationalStatusProvider);
  return status == 'SUSPENDED_FOR_WALLET' ||
      status == 'SUSPENDED_FOR_COD' ||
      CodEngine.isSuspended(ref.read(riderCodDueProvider));
}
