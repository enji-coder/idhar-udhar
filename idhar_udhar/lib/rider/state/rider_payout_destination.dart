import '../data/models/rider_bank_details.dart';

final RegExp bankAccountPattern = RegExp(r'^\d{9,18}$');
final RegExp ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
final RegExp accountHolderPattern = RegExp(r"^[A-Za-z][A-Za-z .'-]{1,79}$");

class BankFieldErrors {
  const BankFieldErrors({
    this.bankName,
    this.holder,
    this.account,
    this.ifsc,
  });

  final String? bankName;
  final String? holder;
  final String? account;
  final String? ifsc;

  bool get isValid =>
      bankName == null && holder == null && account == null && ifsc == null;
}

BankFieldErrors validateBankFields({
  required String bankName,
  required String holderName,
  required String accountNumber,
  required String ifsc,
}) {
  final String account = accountNumber.replaceAll(RegExp(r'\s'), '');
  final String normalizedIfsc = ifsc.trim().toUpperCase();
  final String holder = holderName.trim();
  return BankFieldErrors(
    bankName: bankName.trim().length < 3 ? 'Enter bank name' : null,
    holder: accountHolderPattern.hasMatch(holder)
        ? null
        : 'Enter the account holder name',
    account: bankAccountPattern.hasMatch(account)
        ? null
        : 'Enter a valid account number',
    ifsc: ifscPattern.hasMatch(normalizedIfsc) ? null : 'Enter a valid IFSC',
  );
}

/// Returns an error when the selected method has no saved destination.
/// A saved UPI does not change a BANK selection.
String? withdrawalDestinationError({
  required String? payoutMethod,
  required bool upiSaved,
  required bool bankSaved,
}) {
  if (payoutMethod != 'UPI' && payoutMethod != 'BANK') {
    return 'Choose UPI or bank';
  }
  if (payoutMethod == 'UPI' && !upiSaved) {
    return 'Save a UPI ID before a UPI withdrawal';
  }
  if (payoutMethod == 'BANK' && !bankSaved) {
    return 'Save a bank account before a bank withdrawal';
  }
  return null;
}

class WithdrawalSubmission {
  const WithdrawalSubmission({
    required this.amount,
    required this.payoutMethod,
  });

  final double amount;
  final String payoutMethod;
}

/// Keeps the rider's selected method. A saved UPI never rewrites BANK.
WithdrawalSubmission? withdrawalSubmission({
  required double amount,
  required String? payoutMethod,
  required bool upiSaved,
  required bool bankSaved,
}) {
  if (withdrawalDestinationError(
        payoutMethod: payoutMethod,
        upiSaved: upiSaved,
        bankSaved: bankSaved,
      ) !=
      null) {
    return null;
  }
  return WithdrawalSubmission(amount: amount, payoutMethod: payoutMethod!);
}

/// Persists a payout destination only after the server call succeeds.
/// The returned details are what the screen may store locally.
Future<RiderBankDetails> persistUpiDestination({
  required Future<void> Function(String vpa) saveUpi,
  required RiderBankDetails current,
  required String vpa,
}) async {
  final String trimmed = vpa.trim();
  await saveUpi(trimmed);
  return current.copyWith(upiId: trimmed, upiVerified: false, upiOnServer: true);
}

/// Saves only the bank destination. The existing UPI value is left unchanged.
Future<RiderBankDetails> persistBankDestination({
  required Future<void> Function({
    required String holderName,
    required String accountNumber,
    required String ifsc,
  }) saveBank,
  required RiderBankDetails current,
  required String bankName,
  required String holderName,
  required String accountNumber,
  required String ifsc,
}) async {
  final String account = accountNumber.replaceAll(RegExp(r'\s'), '');
  final String normalizedIfsc = ifsc.trim().toUpperCase();
  final String trimmedHolder = holderName.trim();
  await saveBank(
    holderName: trimmedHolder,
    accountNumber: account,
    ifsc: normalizedIfsc,
  );
  return current.copyWith(
    bankName: bankName.trim(),
    accountHolder: trimmedHolder,
    accountNumber: account,
    ifsc: normalizedIfsc,
    bankOnServer: true,
  );
}

/// Clears the server UPI before the caller may drop the local value.
Future<RiderBankDetails> clearUpiDestination({
  required Future<void> Function() clearUpi,
  required RiderBankDetails current,
}) async {
  await clearUpi();
  return current.copyWith(upiId: '', upiVerified: false, upiOnServer: false);
}

/// Applies a successful destinations GET. Ignores raw instrument fields.
RiderBankDetails destinationsFromServer({
  required RiderBankDetails current,
  required Map<String, Object?> body,
}) {
  final Map<String, Object?> upiMap = _map(body['upi']);
  final Map<String, Object?> bankMap = _map(body['bank']);
  final bool upiAvailable = upiMap['available'] == true;
  final bool bankAvailable = bankMap['available'] == true;
  return current.copyWith(
    upiOnServer: upiAvailable,
    upiId: upiAvailable ? _text(upiMap['vpa_masked']) : '',
    bankOnServer: bankAvailable,
    accountNumber: bankAvailable ? _text(bankMap['account_masked']) : '',
    ifsc: bankAvailable ? _text(bankMap['ifsc']) : current.ifsc,
    accountHolder: bankAvailable ? _text(bankMap['holder_name']) : current.accountHolder,
  );
}

String _text(Object? value) => value is String ? value : '';

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic item) => MapEntry(key.toString(), item as Object?),
    );
  }
  return <String, Object?>{};
}
