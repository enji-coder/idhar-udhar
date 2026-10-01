import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/widgets/otp_box.dart';
import 'package:idhar_udhar/customer/features/authentication/otp_autofill.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exact OTP digits come from the message body', () {
    expect(
      CustomerOtpAutofill.exactOtpDigits(
        'IDHAR UDHAR code 4821. Do not share it.',
        4,
      ),
      '4821',
    );
    expect(
      CustomerOtpAutofill.exactOtpDigits('Your code is 48215', 4),
      isNull,
    );
  });

  testWidgets('the OTP field keeps one-time-code autofill and manual entry', (
    tester,
  ) async {
    String? completed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OTPInputRow(
            onCompleted: (value) => completed = value,
          ),
        ),
      ),
    );

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));

    await tester.enterText(find.byType(TextField), '4821');
    await tester.pump();

    expect(completed, '4821');
    expect(find.text('4'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
