import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/business/business.dart';

/// Display caches only. Never credit/debit here — wallet/COD are server-backed.
final riderCodDueProvider = StateProvider<double>((ref) => 0);

final riderLastSettlementProvider = StateProvider<CodSettlement?>((ref) => null);

bool riderIsSuspended(WidgetRef ref) =>
    CodEngine.isSuspended(ref.read(riderCodDueProvider));
