import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:idhar_udhar/shared/format/inr_format.dart';

import 'customer_invoice.dart';

/// Builds the customer PDF from the stored invoice and the original logo bytes.
Future<Uint8List> buildCustomerInvoicePdf({
  required CustomerInvoice invoice,
  required Uint8List logoBytes,
}) async {
  final pw.MemoryImage logo = pw.MemoryImage(logoBytes);
  final pw.Document document = pw.Document(compress: false);
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Image(logo, height: 52),
            pw.SizedBox(height: 12),
            pw.Text(
              'IDHAR UDHAR',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Invoice ${invoice.invoiceNumber}'),
            pw.Text('CRN ${invoice.crn.isEmpty ? 'Unavailable' : invoice.crn}'),
            pw.Text('Invoice date ${_when(invoice.issuedAt)}'),
            pw.Text('Trip completed ${_when(invoice.tripCompletedAt)}'),
            pw.SizedBox(height: 12),
            pw.Text('Pickup', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(invoice.pickupAddress ?? 'Unavailable'),
            pw.SizedBox(height: 8),
            pw.Text('Drop', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(invoice.dropAddress ?? 'Unavailable'),
            pw.SizedBox(height: 8),
            pw.Text('Vehicle', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(_vehicle(invoice)),
            pw.SizedBox(height: 16),
            ...customerInvoicePdfLines(invoice).map(_moneyRow),
            pw.SizedBox(height: 16),
            pw.Text('Payment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Status ${invoice.paymentStatus ?? 'Unavailable'}'),
            pw.Text('Customer paid ${_bill(invoice.customerPaid)}'),
            pw.Text('Receiver paid ${_inr(invoice.receiverPaid)}'),
            pw.Text('Customer cash ${_bill(invoice.customerPlannedCash)}'),
            pw.Text('Customer online ${_bill(invoice.customerPlannedOnline)}'),
            pw.Text('Receiver cash ${_inr(invoice.receiverPlannedCash)}'),
            pw.Text('Receiver online ${_inr(invoice.receiverPlannedOnline)}'),
          ],
        );
      },
    ),
  );
  return document.save();
}

pw.Widget _moneyRow(({String label, String amount}) line) {
  final String shown = line.label == 'Net payable'
      ? _bill(line.amount)
      : line.label == 'Discount'
          ? _inr(_negative(line.amount))
          : _inr(line.amount);
  final bool total = line.label == 'Net payable';
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Text(
          line.label,
          style: pw.TextStyle(fontWeight: total ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
        pw.Text(
          shown,
          style: pw.TextStyle(fontWeight: total ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      ],
    ),
  );
}

String _vehicle(CustomerInvoice invoice) {
  final String category = invoice.vehicleCategory ?? '';
  final String registration = invoice.vehicleRegistration ?? '';
  final String text = '$category $registration'.trim();
  return text.isEmpty ? 'Unavailable' : text;
}

String _when(String? value) {
  if (value == null || value.isEmpty) {
    return 'Unavailable';
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  return DateFormat('d MMM y, h:mm a').format(parsed.toLocal());
}

String _negative(String amount) {
  if (amount.startsWith('-')) {
    return amount;
  }
  return '-$amount';
}

String _bill(String? amount) {
  if (amount == null || amount.isEmpty) {
    return 'Unavailable';
  }
  final String shown = formatCustomerPayableText(amount);
  if (shown.startsWith('-₹')) {
    return '-INR ${shown.substring(2)}';
  }
  if (shown.startsWith('₹')) {
    return 'INR ${shown.substring(1)}';
  }
  return shown;
}

String _inr(String? amount) {
  if (amount == null || amount.isEmpty) {
    return 'Unavailable';
  }
  final double? value = double.tryParse(amount);
  if (value == null) {
    return amount;
  }
  final String text = value.abs().toStringAsFixed(2);
  return value < 0 ? '-INR $text' : 'INR $text';
}
