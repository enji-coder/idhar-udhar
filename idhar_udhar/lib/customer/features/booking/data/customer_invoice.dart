import 'package:idhar_udhar/shared/api/json_codec.dart';

/// Customer-facing invoice from GET /v1/orders/:id/invoice.
class CustomerInvoice {
  const CustomerInvoice({
    required this.invoiceNumber,
    required this.crn,
    required this.status,
    required this.tripFare,
    required this.discount,
    required this.additionalCharges,
    required this.subtotal,
    required this.rounding,
    required this.netPayable,
    required this.lines,
    this.issuedAt,
    this.tripCompletedAt,
    this.pickupAddress,
    this.dropAddress,
    this.vehicleCategory,
    this.vehicleRegistration,
    this.paymentStatus,
    this.customerPaid,
    this.receiverPaid,
    this.customerPlannedCash,
    this.customerPlannedOnline,
    this.receiverPlannedCash,
    this.receiverPlannedOnline,
  });

  factory CustomerInvoice.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> pickup = jsonObject(json['pickup']);
    final Map<String, Object?> drop = jsonObject(json['drop']);
    final Map<String, Object?> vehicle = jsonObject(json['vehicle']);
    final Map<String, Object?> payment = jsonObject(json['payment']);
    return CustomerInvoice(
      invoiceNumber: jsonString(json['invoice_number']) ?? '',
      crn: jsonString(json['crn']) ?? '',
      status: jsonString(json['status']) ?? '',
      issuedAt: jsonString(json['issued_at']),
      tripCompletedAt: jsonString(json['trip_completed_at']),
      pickupAddress: jsonString(pickup['address']),
      dropAddress: jsonString(drop['address']),
      vehicleCategory: jsonString(vehicle['category']),
      vehicleRegistration: jsonString(vehicle['registration']),
      tripFare: jsonString(json['trip_fare']) ?? '0.00',
      discount: jsonString(json['discount']) ?? '0.00',
      additionalCharges: jsonString(json['additional_charges']) ?? '0.00',
      subtotal: jsonString(json['subtotal']) ?? '0.00',
      rounding: jsonString(json['rounding']) ?? '0.00',
      netPayable: jsonString(json['net_payable']) ?? '0.00',
      lines: jsonList(json['lines'])
          .map(
            (Object? item) => CustomerInvoiceLine.fromJson(jsonObject(item)),
          )
          .toList(growable: false),
      paymentStatus: jsonString(payment['status']),
      customerPaid: jsonString(payment['customer_paid']),
      receiverPaid: jsonString(payment['receiver_paid']),
      customerPlannedCash: jsonString(payment['customer_planned_cash']),
      customerPlannedOnline: jsonString(payment['customer_planned_online']),
      receiverPlannedCash: jsonString(payment['receiver_planned_cash']),
      receiverPlannedOnline: jsonString(payment['receiver_planned_online']),
    );
  }

  final String invoiceNumber;
  final String crn;
  final String status;
  final String? issuedAt;
  final String? tripCompletedAt;
  final String? pickupAddress;
  final String? dropAddress;
  final String? vehicleCategory;
  final String? vehicleRegistration;
  final String tripFare;
  final String discount;
  final String additionalCharges;
  final String subtotal;
  final String rounding;
  final String netPayable;
  final List<CustomerInvoiceLine> lines;
  final String? paymentStatus;
  final String? customerPaid;
  final String? receiverPaid;
  final String? customerPlannedCash;
  final String? customerPlannedOnline;
  final String? receiverPlannedCash;
  final String? receiverPlannedOnline;
}

class CustomerInvoiceLine {
  const CustomerInvoiceLine({
    required this.label,
    required this.amount,
    required this.lineType,
  });

  factory CustomerInvoiceLine.fromJson(Map<String, Object?> json) {
    return CustomerInvoiceLine(
      label: jsonString(json['label']) ?? '',
      amount: jsonString(json['amount']) ?? '0.00',
      lineType: jsonString(json['line_type']) ?? '',
    );
  }

  final String label;
  final String amount;
  final String lineType;
}

/// Download is offered only after the server says the trip is delivered
/// and the stored invoice was returned.
bool showInvoiceDownload({
  required String? canonicalStatus,
  required CustomerInvoice? invoice,
}) {
  return canonicalStatus == 'DELIVERED' && invoice != null;
}

/// Lines printed on the PDF. Header amounts are the authority.
List<({String label, String amount})> customerInvoicePdfLines(
  CustomerInvoice invoice,
) {
  final List<({String label, String amount})> lines =
      <({String label, String amount})>[
    (label: 'Trip Fare', amount: invoice.tripFare),
  ];
  if (invoice.discount != '0.00' && invoice.discount != '-0.00') {
    lines.add((label: 'Discount', amount: invoice.discount));
  }
  if (invoice.additionalCharges != '0.00' &&
      invoice.additionalCharges != '-0.00') {
    lines.add((label: 'Additional charges', amount: invoice.additionalCharges));
  }
  lines.add((label: 'Subtotal', amount: invoice.subtotal));
  lines.add((label: 'Rounding', amount: invoice.rounding));
  lines.add((label: 'Net payable', amount: invoice.netPayable));
  return lines;
}
