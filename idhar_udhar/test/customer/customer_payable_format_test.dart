import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/format/inr_format.dart';

void main() {
  test('customer payable drops .00 and keeps a real fraction', () {
    expect(formatCustomerPayable(125), '₹125');
    expect(formatCustomerPayable(125.00), '₹125');
    expect(formatCustomerPayableText('125.00'), '₹125');
    expect(formatCustomerPayableText('124.89'), formatInr(124.89));
    expect(formatCustomerPayableText('124.89'), contains('124.89'));
  });

  test('rider and company amounts keep two decimal places', () {
    expect(formatInr(147.05), contains('147.05'));
    expect(formatInr(18.75), contains('18.75'));
    expect(formatCustomerPayableText('147.05'), contains('147.05'));
    expect(formatCustomerPayableText('18.75'), contains('18.75'));
    expect(formatInr(147.05), isNot('₹147'));
    expect(formatInr(18.75), isNot('₹19'));
  });
}
