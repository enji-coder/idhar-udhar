import 'package:intl/intl.dart';

/// Display-only INR. Financial values stay in the API and database.
final NumberFormat inrFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

String formatInr(num value) => inrFormat.format(value);

final RegExp _moneyText = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$');

/// Customer payable label. A whole rupee drops the paise (`₹125`).
/// A real fractional amount keeps two decimals. Rider screens stay on [formatInr].
String formatCustomerPayable(num value) {
  final int paise = (value.abs() * 100).round();
  if (paise % 100 != 0) {
    return formatInr(value);
  }
  final String rupees = '${paise ~/ 100}';
  return value < 0 ? '-₹$rupees' : '₹$rupees';
}

/// Same display for API money text such as `125.00` or `147.05`.
String formatCustomerPayableText(String raw) {
  final RegExpMatch? match = _moneyText.firstMatch(raw.trim());
  if (match == null) {
    return raw;
  }
  final String sign = match.group(1)!;
  final String whole = match.group(2)!;
  final String frac = (match.group(3) ?? '').padRight(2, '0');
  if (frac == '00') {
    return '$sign₹$whole';
  }
  return formatInr(double.parse('$sign$whole.$frac'));
}
