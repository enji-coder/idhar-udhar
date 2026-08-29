import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'json_codec.dart';

class RiderWallet {
  const RiderWallet({
    required this.availableBalance,
    required this.walletAccountId,
  });

  final double availableBalance;
  final String walletAccountId;

  factory RiderWallet.fromJson(Map<String, Object?> json) {
    return RiderWallet(
      availableBalance: jsonDouble(json['available_balance']),
      walletAccountId: jsonString(json['wallet_account_id']) ?? '',
    );
  }
}

class RiderCod {
  const RiderCod({
    required this.codDue,
    required this.suspendThreshold,
    required this.suspended,
    this.operationalStatus,
  });

  final double codDue;
  final double suspendThreshold;
  final bool suspended;
  final String? operationalStatus;

  factory RiderCod.fromJson(Map<String, Object?> json) {
    return RiderCod(
      codDue: jsonDouble(json['cod_due']),
      suspendThreshold: jsonDouble(json['suspend_threshold']),
      suspended: jsonBool(json['suspended']),
      operationalStatus: jsonString(json['cod_operational_status']),
    );
  }
}

class RiderEarningRow {
  const RiderEarningRow({
    required this.orderId,
    required this.displayId,
    required this.tripFare,
    required this.riderAmount,
    required this.frozenAt,
  });

  final String orderId;
  final String displayId;
  final double tripFare;
  final double riderAmount;
  final DateTime frozenAt;

  factory RiderEarningRow.fromJson(Map<String, Object?> json) {
    return RiderEarningRow(
      orderId: jsonString(json['order_id']) ?? '',
      displayId: jsonString(json['display_id']) ?? '',
      tripFare: jsonDouble(json['trip_fare']),
      riderAmount: jsonDouble(json['rider_amount']),
      frozenAt: jsonDate(json['frozen_at']) ?? DateTime.now(),
    );
  }
}

class WalletApi {
  WalletApi(this._client);

  final ApiClient _client;
  final Uuid _uuid = const Uuid();

  Future<RiderWallet> wallet() async {
    return RiderWallet.fromJson(await _client.get('/v1/rider/wallet'));
  }

  Future<List<Map<String, Object?>>> walletLedger() async {
    final Map<String, Object?> body =
        await _client.get('/v1/rider/wallet/ledger');
    return jsonList(body['entries']).map(jsonObject).toList(growable: false);
  }

  Future<void> recharge(double amount) async {
    await _client.post(
      '/v1/rider/wallet/recharge',
      data: <String, String>{'amount': amount.toStringAsFixed(2)},
      headers: <String, String>{'Idempotency-Key': _uuid.v4()},
    );
  }

  Future<RiderCod> cod() async {
    return RiderCod.fromJson(await _client.get('/v1/rider/cod'));
  }

  Future<List<Map<String, Object?>>> codLedger() async {
    final Map<String, Object?> body = await _client.get('/v1/rider/cod/ledger');
    return jsonList(body['entries']).map(jsonObject).toList(growable: false);
  }

  Future<void> settle(double amount) async {
    await _client.post(
      '/v1/rider/cod/settle',
      data: <String, String>{'amount': amount.toStringAsFixed(2)},
      headers: <String, String>{'Idempotency-Key': _uuid.v4()},
    );
  }

  Future<List<RiderEarningRow>> earnings() async {
    final Map<String, Object?> body = await _client.get('/v1/rider/earnings');
    return jsonList(body['earnings'])
        .map((Object? item) => RiderEarningRow.fromJson(jsonObject(item)))
        .toList(growable: false);
  }
}
