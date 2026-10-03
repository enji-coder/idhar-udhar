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

class CustomerWalletEntry {
  const CustomerWalletEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.isCredit,
    this.date,
  });

  final String id;
  final String title;
  final double amount;
  final bool isCredit;
  final DateTime? date;

  factory CustomerWalletEntry.fromJson(Map<String, Object?> json) {
    final String type = jsonString(json['entry_type']) ?? '';
    return CustomerWalletEntry(
      id: jsonString(json['wallet_ledger_id']) ?? '',
      title: type.isEmpty ? 'Wallet' : type,
      amount: jsonDouble(json['amount']),
      isCredit: (jsonString(json['direction']) ?? '').toUpperCase() == 'CREDIT',
      date: jsonDate(json['created_at']),
    );
  }
}

class WalletTopUpSession {
  const WalletTopUpSession({
    required this.paymentTransactionId,
    required this.amount,
    required this.paymentSessionId,
    required this.cashfreeOrderId,
    required this.environment,
  });

  final String paymentTransactionId;
  final double amount;
  final String paymentSessionId;
  final String cashfreeOrderId;
  final String environment;

  factory WalletTopUpSession.fromJson(Map<String, Object?> json) {
    return WalletTopUpSession(
      paymentTransactionId: jsonString(json['payment_transaction_id']) ?? '',
      amount: jsonDouble(json['amount']),
      paymentSessionId: jsonString(json['payment_session_id']) ?? '',
      cashfreeOrderId: jsonString(json['cashfree_order_id']) ?? '',
      environment: jsonString(json['cashfree_environment']) ?? '',
    );
  }

  bool get canOpenCheckout =>
      paymentSessionId.isNotEmpty &&
      cashfreeOrderId.isNotEmpty &&
      environment.isNotEmpty;
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

  /// Creates a Cashfree PENDING top-up. Does not credit the wallet.
  Future<WalletTopUpSession> beginTopUp(double amount) async {
    return WalletTopUpSession.fromJson(
      await _client.post(
        '/v1/rider/wallet/recharge',
        data: <String, String>{'amount': amount.toStringAsFixed(2)},
        headers: <String, String>{'Idempotency-Key': _uuid.v4()},
      ),
    );
  }

  Future<Map<String, Object?>> withdraw({
    required double amount,
    required String payoutMethod,
  }) async {
    return _client.post(
      '/v1/rider/wallet/withdraw',
      data: <String, String>{
        'amount': amount.toStringAsFixed(2),
        'payout_method': payoutMethod,
      },
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

  Future<RiderWallet> customerWallet() async {
    return RiderWallet.fromJson(await _client.get('/v1/customer/wallet'));
  }

  Future<List<CustomerWalletEntry>> customerLedger() async {
    final Map<String, Object?> body =
        await _client.get('/v1/customer/wallet/ledger');
    return jsonList(body['entries'])
        .map(
          (Object? item) => CustomerWalletEntry.fromJson(jsonObject(item)),
        )
        .toList(growable: false);
  }

  Future<List<RiderEarningRow>> earnings() async {
    final Map<String, Object?> body = await _client.get('/v1/rider/earnings');
    return jsonList(body['earnings'])
        .map((Object? item) => RiderEarningRow.fromJson(jsonObject(item)))
        .toList(growable: false);
  }
}
