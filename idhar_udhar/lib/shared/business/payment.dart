import 'fare_engine.dart';

/// WHO pays — separate from HOW they pay.
enum PaymentPayer { customer, receiver }

enum PaymentWhoPays { customer, receiver, split }

enum PayerMethodMode { online, cash, split }

/// HOW they pay — separate from WHO pays.
enum TripPayMethod { online, cash }

enum TripPaymentStatus { unpaid, partiallyPaid, paid }

extension TripPaymentStatusX on TripPaymentStatus {
  String get label {
    switch (this) {
      case TripPaymentStatus.unpaid:
        return 'UNPAID';
      case TripPaymentStatus.partiallyPaid:
        return 'PARTIALLY_PAID';
      case TripPaymentStatus.paid:
        return 'PAID';
    }
  }
}

class PaymentResponsibility {
  const PaymentResponsibility({
    required this.totalAmount,
    required this.customerAmount,
    required this.receiverAmount,
  });

  final double totalAmount;
  final double customerAmount;
  final double receiverAmount;

  bool get isValid =>
      FareEngine.round2(customerAmount + receiverAmount) ==
          FareEngine.round2(totalAmount) &&
      customerAmount >= 0 &&
      receiverAmount >= 0;
}

class PaymentTxn {
  const PaymentTxn({
    required this.id,
    required this.orderId,
    required this.payer,
    required this.method,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.referenceId,
  });

  final String id;
  final String orderId;
  final PaymentPayer payer;
  final TripPayMethod method;
  final double amount;
  final TripPaymentStatus status;
  final DateTime createdAt;
  final String? referenceId;

  bool get isPaid => status == TripPaymentStatus.paid;

  PaymentTxn copyWith({TripPaymentStatus? status, String? referenceId}) {
    return PaymentTxn(
      id: id,
      orderId: orderId,
      payer: payer,
      method: method,
      amount: amount,
      status: status ?? this.status,
      createdAt: createdAt,
      referenceId: referenceId ?? this.referenceId,
    );
  }
}

class PaymentAllocation {
  const PaymentAllocation({
    this.customerOnline = 0,
    this.customerCash = 0,
    this.receiverOnline = 0,
    this.receiverCash = 0,
  });

  final double customerOnline;
  final double customerCash;
  final double receiverOnline;
  final double receiverCash;

  double get customerAllocated =>
      FareEngine.round2(customerOnline + customerCash);
  double get receiverAllocated =>
      FareEngine.round2(receiverOnline + receiverCash);
  double get cashTotal => FareEngine.round2(customerCash + receiverCash);
  double get onlineTotal => FareEngine.round2(customerOnline + receiverOnline);
}

class PaymentPlan {
  const PaymentPlan({
    required this.responsibility,
    required this.allocation,
    this.transactions = const [],
  });

  final PaymentResponsibility responsibility;
  final PaymentAllocation allocation;
  final List<PaymentTxn> transactions;

  double paidFor(PaymentPayer payer) {
    return FareEngine.round2(
      transactions
          .where((t) => t.payer == payer && t.isPaid)
          .fold<double>(0, (sum, t) => sum + t.amount),
    );
  }

  double get customerPaid => paidFor(PaymentPayer.customer);
  double get receiverPaid => paidFor(PaymentPayer.receiver);
  double get totalPaid => FareEngine.round2(customerPaid + receiverPaid);
  double get outstanding =>
      FareEngine.round2(responsibility.totalAmount - totalPaid);

  TripPaymentStatus statusFor(PaymentPayer payer) {
    final double due = payer == PaymentPayer.customer
        ? responsibility.customerAmount
        : responsibility.receiverAmount;
    return PaymentEngine.statusFrom(paid: paidFor(payer), due: due);
  }

  TripPaymentStatus get overallStatus => PaymentEngine.statusFrom(
        paid: totalPaid,
        due: responsibility.totalAmount,
      );
}

abstract final class PaymentEngine {
  static PaymentResponsibility responsibility({
    required double totalAmount,
    required double customerAmount,
  }) {
    final double total = FareEngine.round2(totalAmount);
    final double customer = FareEngine.round2(customerAmount);
    return PaymentResponsibility(
      totalAmount: total,
      customerAmount: customer,
      receiverAmount: FareEngine.round2(total - customer),
    );
  }

  static String? validate({
    required PaymentResponsibility responsibility,
    required PaymentAllocation allocation,
  }) {
    if (!responsibility.isValid) {
      return 'Customer and receiver amounts must add up to the total';
    }
    if (FareEngine.round2(allocation.customerAllocated) !=
        FareEngine.round2(responsibility.customerAmount)) {
      return 'Customer Online + Cash must equal customer amount';
    }
    if (FareEngine.round2(allocation.receiverAllocated) !=
        FareEngine.round2(responsibility.receiverAmount)) {
      return 'Receiver Online + Cash must equal receiver amount';
    }
    if (allocation.customerOnline < 0 ||
        allocation.customerCash < 0 ||
        allocation.receiverOnline < 0 ||
        allocation.receiverCash < 0) {
      return 'Payment amounts cannot be negative';
    }
    return null;
  }

  static TripPaymentStatus statusFrom({
    required double paid,
    required double due,
  }) {
    final double p = FareEngine.round2(paid);
    final double d = FareEngine.round2(due);
    if (d <= 0) return TripPaymentStatus.paid;
    if (p <= 0) return TripPaymentStatus.unpaid;
    if (p + 0.009 < d) return TripPaymentStatus.partiallyPaid;
    return TripPaymentStatus.paid;
  }

  /// Planned transactions at booking. Online is stored UNPAID until a
  /// payment provider confirms (do not fake success). Cash is UNPAID until
  /// collected.
  static List<PaymentTxn> plannedTransactions({
    required String orderId,
    required PaymentAllocation allocation,
    DateTime? at,
  }) {
    final DateTime stamp = at ?? DateTime.now();
    final List<PaymentTxn> rows = <PaymentTxn>[];
    void add(PaymentPayer payer, TripPayMethod method, double amount, int i) {
      if (FareEngine.round2(amount) <= 0) return;
      rows.add(
        PaymentTxn(
          id: '$orderId-pay-$i',
          orderId: orderId,
          payer: payer,
          method: method,
          amount: FareEngine.round2(amount),
          status: TripPaymentStatus.unpaid,
          createdAt: stamp,
        ),
      );
    }

    add(PaymentPayer.customer, TripPayMethod.online, allocation.customerOnline, 1);
    add(PaymentPayer.customer, TripPayMethod.cash, allocation.customerCash, 2);
    add(PaymentPayer.receiver, TripPayMethod.online, allocation.receiverOnline, 3);
    add(PaymentPayer.receiver, TripPayMethod.cash, allocation.receiverCash, 4);
    return rows;
  }

  static PaymentPlan build({
    required PaymentResponsibility responsibility,
    required PaymentAllocation allocation,
    required String orderId,
  }) {
    return PaymentPlan(
      responsibility: responsibility,
      allocation: allocation,
      transactions: plannedTransactions(
        orderId: orderId,
        allocation: allocation,
      ),
    );
  }

  /// Cash collected by the rider that exceeds rider earning is COD Due.
  static double cashCollected(PaymentPlan plan) => plan.allocation.cashTotal;
}
