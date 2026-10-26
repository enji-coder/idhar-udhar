import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/data/models/rider_bank_details.dart';
import 'package:idhar_udhar/rider/state/rider_payout_destination.dart';

void main() {
  test('UPI save updates local details only after the API succeeds', () async {
    final List<String> calls = <String>[];
    final RiderBankDetails saved = await persistUpiDestination(
      saveUpi: (String vpa) async {
        calls.add(vpa);
      },
      current: RiderBankDetails.empty,
      vpa: ' name@upi ',
    );
    expect(calls, <String>['name@upi']);
    expect(saved.upiId, 'name@upi');
  });

  test('UPI API failure does not produce saved local details', () async {
    await expectLater(
      persistUpiDestination(
        saveUpi: (String vpa) async {
          throw StateError('api failed for $vpa');
        },
        current: RiderBankDetails.empty,
        vpa: 'name@upi',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('bank save calls saveBank once and never saveUpi', () async {
    final List<String> calls = <String>[];
    final RiderBankDetails saved = await persistBankDestination(
      saveBank: ({
        required String holderName,
        required String accountNumber,
        required String ifsc,
      }) async {
        calls.add('bank:$holderName:$accountNumber:$ifsc');
      },
      current: RiderBankDetails.empty.copyWith(upiId: 'keep@upi'),
      bankName: 'HDFC',
      holderName: ' Ravi Kumar ',
      accountNumber: '1234 5678 9012',
      ifsc: 'hdfc0001234',
    );
    expect(calls, <String>[
      'bank:Ravi Kumar:123456789012:HDFC0001234',
    ]);
    expect(saved.accountNumber, '123456789012');
    expect(saved.ifsc, 'HDFC0001234');
    expect(saved.upiId, 'keep@upi');
    expect(saved.bankOnServer, isTrue);
    expect(saved.upiOnServer, isFalse);
  });

  test('bank API failure does not return local details as saved', () async {
    var bankCalls = 0;
    await expectLater(
      persistBankDestination(
        saveBank: ({
          required String holderName,
          required String accountNumber,
          required String ifsc,
        }) async {
          bankCalls += 1;
          throw StateError('bank failed');
        },
        current: RiderBankDetails.empty,
        bankName: 'HDFC',
        holderName: 'Ravi Kumar',
        accountNumber: '123456789012',
        ifsc: 'HDFC0001234',
      ),
      throwsA(isA<StateError>()),
    );
    expect(bankCalls, 1);
  });

  test('UPI delete clears local state only after the clear API succeeds', () async {
    var calls = 0;
    final RiderBankDetails saved = await clearUpiDestination(
      clearUpi: () async {
        calls += 1;
      },
      current: RiderBankDetails.empty.copyWith(
        upiId: 'name@upi',
        accountNumber: '123456789012',
      ),
    );
    expect(calls, 1);
    expect(saved.upiId, isEmpty);
    expect(saved.accountNumber, '123456789012');
  });

  test('UPI delete API failure preserves the local UPI', () async {
    const RiderBankDetails current = RiderBankDetails(
      bankName: 'HDFC',
      accountHolder: 'Ravi Kumar',
      accountNumber: '123456789012',
      ifsc: 'HDFC0001234',
      upiId: 'name@upi',
    );
    await expectLater(
      clearUpiDestination(
        clearUpi: () async {
          throw StateError('clear failed');
        },
        current: current,
      ),
      throwsA(isA<StateError>()),
    );
    expect(current.upiId, 'name@upi');
  });

  test('choosing BANK submits BANK even when a UPI ID is saved', () {
    final WithdrawalSubmission? submission = withdrawalSubmission(
      amount: 10,
      payoutMethod: 'BANK',
      upiSaved: true,
      bankSaved: true,
    );
    expect(submission?.payoutMethod, 'BANK');
  });

  test('choosing UPI submits UPI', () {
    final WithdrawalSubmission? submission = withdrawalSubmission(
      amount: 10,
      payoutMethod: 'UPI',
      upiSaved: true,
      bankSaved: true,
    );
    expect(submission?.payoutMethod, 'UPI');
  });

  test('a missing selected destination is not replaced by the other method', () {
    expect(
      withdrawalSubmission(
        amount: 10,
        payoutMethod: 'BANK',
        upiSaved: true,
        bankSaved: false,
      ),
      isNull,
    );
    expect(
      withdrawalSubmission(
        amount: 10,
        payoutMethod: 'UPI',
        upiSaved: false,
        bankSaved: true,
      ),
      isNull,
    );
  });

  test('bank account and IFSC validation match the backend rules', () {
    final BankFieldErrors valid = validateBankFields(
      bankName: 'HDFC',
      holderName: 'Ravi Kumar',
      accountNumber: '1234 5678 901',
      ifsc: 'hdfc0001234',
    );
    expect(valid.isValid, isTrue);

    final BankFieldErrors shortAccount = validateBankFields(
      bankName: 'HDFC',
      holderName: 'Ravi Kumar',
      accountNumber: '12345678',
      ifsc: 'HDFC0001234',
    );
    expect(shortAccount.account, 'Enter a valid account number');

    final BankFieldErrors longAccount = validateBankFields(
      bankName: 'HDFC',
      holderName: 'Ravi Kumar',
      accountNumber: '1234567890123456789',
      ifsc: 'HDFC0001234',
    );
    expect(longAccount.account, 'Enter a valid account number');

    final BankFieldErrors badIfsc = validateBankFields(
      bankName: 'HDFC',
      holderName: 'Ravi Kumar',
      accountNumber: '123456789',
      ifsc: 'HDFC100123',
    );
    expect(badIfsc.ifsc, 'Enter a valid IFSC');
  });

  test('a local UPI string is not a saved destination', () {
    expect(
      withdrawalSubmission(
        amount: 10,
        payoutMethod: 'UPI',
        upiSaved: false,
        bankSaved: false,
      ),
      isNull,
    );
  });

  test('reloading destinations keeps masks and server availability only', () {
    const RiderBankDetails current = RiderBankDetails(
      bankName: 'Local',
      accountHolder: 'Local Holder',
      accountNumber: '999999999999',
      ifsc: 'SBIN0000001',
      upiId: 'typed@upi',
    );
    final RiderBankDetails loaded = destinationsFromServer(
      current: current,
      body: <String, Object?>{
        'upi': <String, Object?>{
          'available': true,
          'vpa_masked': 't***@upi',
          'vpa': 'typed@upi',
          'status': 'REGISTERED',
        },
        'bank': <String, Object?>{
          'available': true,
          'account_masked': 'XXXXXX9012',
          'account_number': '123456789012',
          'ifsc': 'HDFC0001234',
          'holder_name': 'Ravi Kumar',
        },
      },
    );
    expect(loaded.upiOnServer, isTrue);
    expect(loaded.bankOnServer, isTrue);
    expect(loaded.upiId, 't***@upi');
    expect(loaded.accountNumber, 'XXXXXX9012');
    expect(loaded.upiId.contains('typed@upi'), isFalse);
    expect(loaded.accountNumber.contains('123456789012'), isFalse);
  });
}
