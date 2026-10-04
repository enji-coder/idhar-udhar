import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/otp/otp_autofill.dart';

void main() {
  test('exactOtpDigits extracts a bounded OTP from an SMS body', () {
    expect(
      OtpAutofill.exactOtpDigits('<#> Your OTP is 4281\nAbCdEfGhIjK', 4),
      '4281',
    );
    expect(OtpAutofill.exactOtpDigits('code 12', 4), isNull);
    expect(OtpAutofill.exactOtpDigits('no digits here', 4), isNull);
  });
}
