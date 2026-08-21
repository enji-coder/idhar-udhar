import 'cancellation.dart';
import 'cod.dart';
import 'company_office.dart';
import 'finance.dart';

/// Shared Admin-controlled rules used by Customer and Rider UIs.
/// Production loads this from the backend. Mock uses defaults, with optional HTTP.
class PlatformRules {
  PlatformRules({
    this.payment = const PaymentSettings(),
    CancellationConfig? cancellation,
    CompanyOffice? office,
    this.codSuspendThreshold = CodEngine.suspendThreshold,
  })  : cancellation = cancellation ?? CancellationConfig.defaults(),
        office = office ?? CompanyOffice.ahmedabadPlaceholder;

  final PaymentSettings payment;
  final CancellationConfig cancellation;
  final CompanyOffice office;
  final double codSuspendThreshold;

  static PlatformRules current = PlatformRules();
}
