import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/features/booking/data/customer_invoice.dart';
import 'package:idhar_udhar/customer/features/booking/data/customer_invoice_pdf.dart';

CustomerInvoice sample() {
  return CustomerInvoice.fromJson(<String, Object?>{
    'invoice_number': 'INV-IU-AMD-0000000001',
    'crn': 'IU-CRN-AMD-0000000001',
    'status': 'ISSUED',
    'issued_at': '2026-08-14T10:15:00.000Z',
    'trip_completed_at': '2026-08-14T11:00:00.000Z',
    'pickup': <String, Object?>{'address': 'Pickup lane'},
    'drop': <String, Object?>{'address': 'Drop lane'},
    'vehicle': <String, Object?>{
      'category': 'Bike',
      'registration': 'GJ01AB1234',
    },
    'lines': <Object?>[
      <String, Object?>{
        'sequence': 0,
        'line_type': 'TRIP_FARE',
        'label': 'Trip Fare',
        'amount': '135.00',
      },
    ],
    'trip_fare': '135.00',
    'discount': '10.00',
    'additional_charges': '5.00',
    'subtotal': '130.00',
    'rounding': '-0.40',
    'net_payable': '129.60',
    'payment': <String, Object?>{
      'status': 'PAID',
      'customer_paid': '129.60',
      'receiver_paid': '0.00',
    },
  });
}

void main() {
  test('download is available only for a delivered order with an invoice', () {
    final CustomerInvoice invoice = sample();
    expect(
      showInvoiceDownload(canonicalStatus: 'IN_TRANSIT', invoice: invoice),
      isFalse,
    );
    expect(
      showInvoiceDownload(canonicalStatus: 'CANCELLED', invoice: invoice),
      isFalse,
    );
    expect(
      showInvoiceDownload(canonicalStatus: 'DELIVERED', invoice: null),
      isFalse,
    );
    expect(
      showInvoiceDownload(canonicalStatus: 'DELIVERED', invoice: invoice),
      isTrue,
    );
    expect(
      showInvoiceDownload(canonicalStatus: 'DELIVERED', invoice: null),
      isFalse,
    );
  });

  test('a demo delivered flag cannot produce an official invoice', () {
    expect(
      showInvoiceDownload(canonicalStatus: 'DELIVERED', invoice: null),
      isFalse,
    );
    expect(
      showInvoiceDownload(canonicalStatus: null, invoice: sample()),
      isFalse,
    );
  });

  test('pdf embeds the original logo and the stored CRN and net payable', () async {
    final File logoFile = File('assets/customer/logos/idhar_udhar_logo.png');
    final List<int> logo = await logoFile.readAsBytes();
    expect(logo.length, greaterThan(1000));
    expect(logo.take(4).toList(), <int>[0x89, 0x50, 0x4E, 0x47]);
    final Uint8List bytes = await buildCustomerInvoicePdf(
      invoice: sample(),
      logoBytes: Uint8List.fromList(logo),
    );
    final String text = String.fromCharCodes(bytes);
    expect(text, contains('%PDF'));
    expect(text, contains('IU-CRN-AMD-0000000001'));
    expect(text, contains('129.60'));
    expect(text, contains('/Image'));
    expect(text.contains('GSTIN'), isFalse);
    expect(text.contains('Packaging'), isFalse);
    expect(text.contains('Sent to'), isFalse);
    expect(text.toLowerCase().contains('commission'), isFalse);
    expect(text.contains('Rider share'), isFalse);
  });
}
