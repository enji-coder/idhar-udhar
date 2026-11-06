import 'package:intl/intl.dart';

/// Display-only INR. Financial values stay in the API and database.
final NumberFormat inrFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

String formatInr(num value) => inrFormat.format(value);
