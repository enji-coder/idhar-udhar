import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/state/session_provider.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';

void main() {
  test('customer session does not seed a wallet balance', () {
    expect(const SessionState().walletBalance, 0);
  });

  test('wallet ledger rows come only from the response', () {
    final CustomerWalletEntry entry = CustomerWalletEntry.fromJson(
      <String, Object?>{
        'wallet_ledger_id': 'ledger-1',
        'direction': 'DEBIT',
        'amount': '0.00',
        'entry_type': 'ORDER',
        'created_at': '2026-01-02T00:00:00.000Z',
      },
    );

    expect(entry.id, 'ledger-1');
    expect(entry.title, 'ORDER');
    expect(entry.amount, 0);
    expect(entry.isCredit, isFalse);
    expect(entry.date, isNotNull);
  });
}
