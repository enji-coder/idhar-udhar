import 'package:uuid/uuid.dart';

import '../payments/cashfree_checkout_trace.dart';
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
    this.walletSuspendFloor = -100,
    this.rechargeToResume = 0,
  });

  final double codDue;
  final double suspendThreshold;
  final bool suspended;
  final String? operationalStatus;
  final double walletSuspendFloor;
  final double rechargeToResume;

  factory RiderCod.fromJson(Map<String, Object?> json) {
    return RiderCod(
      codDue: jsonDouble(json['cod_due']),
      suspendThreshold: jsonDouble(json['suspend_threshold']),
      suspended: jsonBool(json['suspended']),
      operationalStatus: jsonString(json['cod_operational_status']),
      walletSuspendFloor: json['wallet_suspend_floor'] == null
          ? -100
          : jsonDouble(json['wallet_suspend_floor']),
      rechargeToResume: json['recharge_to_resume'] == null
          ? 0
          : jsonDouble(json['recharge_to_resume']),
    );
  }
}

class RiderEarningRow {
  const RiderEarningRow({
    required this.orderId,
    required this.displayId,
    required this.tripFare,
    required this.riderAmount,
    this.frozenAt,
    this.companyAmount,
    this.settlementStatus,
    this.settlementState,
    this.cashCollected,
    this.walletCredited,
    this.codApplied,
    this.companySharePosted,
    this.walletCompanyDebit,
  });

  final String orderId;
  final String displayId;
  final double tripFare;
  final double riderAmount;

  /// `frozen_at` from the earnings snapshot. Null when the payload omits it.
  final DateTime? frozenAt;

  /// Frozen company share from the same snapshot. Null on older payloads.
  final double? companyAmount;

  /// CREDITED, APPLIED_TO_COD, CREDITED_AND_COD, PENDING, or CASH.
  final String? settlementStatus;

  /// SETTLED or PENDING. Null when the server did not send it.
  final String? settlementState;

  final double? cashCollected;
  final double? walletCredited;
  final double? codApplied;
  final double? companySharePosted;
  final double? walletCompanyDebit;

  factory RiderEarningRow.fromJson(Map<String, Object?> json) {
    return RiderEarningRow(
      orderId: jsonString(json['order_id']) ?? '',
      displayId: jsonString(json['display_id']) ?? '',
      tripFare: jsonDouble(json['trip_fare']),
      riderAmount: jsonDouble(json['rider_amount']),
      frozenAt: jsonDate(json['frozen_at']),
      companyAmount: json['company_commission_amount'] == null
          ? null
          : jsonDouble(json['company_commission_amount']),
      settlementStatus: jsonString(json['settlement_status']),
      settlementState: jsonString(json['settlement_state']),
      cashCollected: json['cash_collected'] == null
          ? null
          : jsonDouble(json['cash_collected']),
      walletCredited: json['wallet_credited_amount'] == null
          ? null
          : jsonDouble(json['wallet_credited_amount']),
      codApplied: json['cod_applied_amount'] == null
          ? null
          : jsonDouble(json['cod_applied_amount']),
      companySharePosted: json['company_share_posted'] == null
          ? null
          : jsonDouble(json['company_share_posted']),
      walletCompanyDebit: json['wallet_company_debit'] == null
          ? null
          : jsonDouble(json['wallet_company_debit']),
    );
  }
}

/// Rider-facing sentence for a settlement status. Null when the server omitted it.
String? earningSettlementLabel(String? status) {
  switch (status) {
    case 'CREDITED':
      return 'Credited to wallet';
    case 'APPLIED_TO_COD':
      return 'Applied to COD Due';
    case 'CREDITED_AND_COD':
      return 'Part credited, part applied to COD Due';
    case 'CASH':
      return 'Cash kept by you';
    case 'PENDING':
      return 'Pending online payment';
    default:
      return null;
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

class WalletTopUpPaymentStatus {
  const WalletTopUpPaymentStatus({
    required this.paymentTransactionId,
    required this.transactionStatus,
  });

  final String paymentTransactionId;
  final String transactionStatus;

  factory WalletTopUpPaymentStatus.fromJson(Map<String, Object?> json) {
    return WalletTopUpPaymentStatus(
      paymentTransactionId: jsonString(json['payment_transaction_id']) ?? '',
      transactionStatus: jsonString(json['transaction_status']) ?? '',
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

  /// Creates a Cashfree PENDING top-up. Does not credit the wallet.
  Future<WalletTopUpSession> beginTopUp(double amount) async {
    final Stopwatch session = Stopwatch()..start();
    try {
      final WalletTopUpSession created = WalletTopUpSession.fromJson(
        await _client.post(
          '/v1/rider/wallet/recharge',
          data: <String, String>{'amount': amount.toStringAsFixed(2)},
          headers: <String, String>{'Idempotency-Key': _uuid.v4()},
        ),
      );
      traceCashfreeCheckout(
        'payment_session_created',
        elapsedMs: session.elapsedMilliseconds,
        result: 'ok',
      );
      return created;
    } catch (_) {
      traceCashfreeCheckout(
        'payment_session_created',
        elapsedMs: session.elapsedMilliseconds,
        result: 'error',
      );
      rethrow;
    }
  }

  /// Server-side Cashfree retrieve + settle for a rider top-up. Does not trust SDK.
  Future<WalletTopUpPaymentStatus> verifyTopUp(String paymentTransactionId) async {
    return WalletTopUpPaymentStatus.fromJson(
      await _client.post(
        '/v1/rider/wallet/transactions/$paymentTransactionId/verify',
        data: <String, Object?>{},
      ),
    );
  }

  Future<Map<String, Object?>> destinations() async {
    return _client.get('/v1/rider/payout-destinations');
  }

  Future<void> clearUpi() async {
    await _client.post('/v1/rider/payout-destinations/upi/clear');
  }

  Future<void> saveUpi(String vpa) async {
    await _client.post(
      '/v1/rider/payout-destinations/upi',
      data: <String, String>{'vpa': vpa},
    );
  }

  Future<void> saveBank({
    required String holderName,
    required String accountNumber,
    required String ifsc,
  }) async {
    await _client.post(
      '/v1/rider/payout-destinations/bank',
      data: <String, String>{
        'holder_name': holderName,
        'account_number': accountNumber,
        'ifsc': ifsc,
      },
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
