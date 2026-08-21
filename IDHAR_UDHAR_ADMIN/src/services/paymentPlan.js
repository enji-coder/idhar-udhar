import { round2 } from './commission';

export function paymentStatusFrom({ paid = 0, due = 0 }) {
  const p = round2(paid);
  const d = round2(due);
  if (d <= 0) return 'PAID';
  if (p <= 0) return 'UNPAID';
  if (p + 0.009 < d) return 'PARTIALLY_PAID';
  return 'PAID';
}

export function validatePaymentPlan({ totalAmount, customerAmount, receiverAmount, allocation }) {
  const total = round2(totalAmount);
  const customer = round2(customerAmount);
  const receiver = round2(receiverAmount);
  if (customer < 0 || receiver < 0) return 'Payment amounts cannot be negative';
  if (round2(customer + receiver) !== total) {
    return 'Customer and receiver amounts must add up to the total';
  }
  const customerAllocated = round2((allocation?.customerOnline || 0) + (allocation?.customerCash || 0));
  const receiverAllocated = round2((allocation?.receiverOnline || 0) + (allocation?.receiverCash || 0));
  if (customerAllocated !== customer) return 'Customer Online + Cash must equal customer amount';
  if (receiverAllocated !== receiver) return 'Receiver Online + Cash must equal receiver amount';
  return null;
}

function isOnlineLabel(value) {
  const method = `${value || ''}`.toLowerCase();
  return method !== 'cash';
}

export function methodsSummary(allocation = {}) {
  const parts = [];
  if (round2(allocation.customerOnline) > 0) parts.push(`Customer Online ₹${round2(allocation.customerOnline)}`);
  if (round2(allocation.customerCash) > 0) parts.push(`Customer Cash ₹${round2(allocation.customerCash)}`);
  if (round2(allocation.receiverOnline) > 0) parts.push(`Receiver Online ₹${round2(allocation.receiverOnline)}`);
  if (round2(allocation.receiverCash) > 0) parts.push(`Receiver Cash ₹${round2(allocation.receiverCash)}`);
  return parts.join(' · ') || 'UNPAID';
}

export function plannedTransactions(orderId, allocation = {}) {
  const rows = [];
  const add = (payer, method, amount, index) => {
    const value = round2(amount);
    if (value <= 0) return;
    rows.push({
      id: `${orderId}-pay-${index}`,
      orderId,
      payer,
      method,
      amount: value,
      status: 'UNPAID',
      createdAt: new Date().toISOString(),
    });
  };
  add('CUSTOMER', 'ONLINE', allocation.customerOnline, 1);
  add('CUSTOMER', 'CASH', allocation.customerCash, 2);
  add('RECEIVER', 'ONLINE', allocation.receiverOnline, 3);
  add('RECEIVER', 'CASH', allocation.receiverCash, 4);
  return rows;
}

export function paidFromTransactions(transactions = [], payer) {
  return round2(
    transactions
      .filter((row) => row.payer === payer && `${row.status}`.toUpperCase() === 'PAID')
      .reduce((sum, row) => sum + Number(row.amount || 0), 0),
  );
}

export function attachPaymentPlan(order = {}) {
  const total = round2(order.amount || order.tripFare || 0);
  if (order.paymentPlan) {
    const plan = order.paymentPlan;
    const customerPaid = paidFromTransactions(plan.transactions, 'CUSTOMER');
    const receiverPaid = paidFromTransactions(plan.transactions, 'RECEIVER');
    const customerDue = round2(plan.customerResponsibility ?? total);
    const receiverDue = round2(plan.receiverResponsibility ?? 0);
    const overall = paymentStatusFrom({ paid: customerPaid + receiverPaid, due: total });
    return {
      ...order,
      paymentPlan: plan,
      customerResponsibility: customerDue,
      receiverResponsibility: receiverDue,
      customerPaid,
      receiverPaid,
      outstandingAmount: round2(total - customerPaid - receiverPaid),
      paymentStatus: overall,
      payment: methodsSummary(plan.allocation) || order.payment,
    };
  }

  const customerAmount = round2(order.customerResponsibility ?? total);
  const receiverAmount = round2(order.receiverResponsibility ?? round2(total - customerAmount));
  const online = isOnlineLabel(order.payment);
  const allocation = {
    customerOnline: online ? customerAmount : 0,
    customerCash: online ? 0 : customerAmount,
    receiverOnline: online ? receiverAmount : 0,
    receiverCash: online ? 0 : receiverAmount,
  };
  const transactions = order.paymentTransactions?.length
    ? order.paymentTransactions
    : plannedTransactions(order.id, allocation);
  const plan = {
    totalAmount: total,
    customerResponsibility: customerAmount,
    receiverResponsibility: receiverAmount,
    allocation,
    transactions,
  };
  const customerPaid = paidFromTransactions(transactions, 'CUSTOMER');
  const receiverPaid = paidFromTransactions(transactions, 'RECEIVER');
  const seededStatus = `${order.paymentStatus || ''}`.toUpperCase();
  const overall = ['PAID', 'PARTIALLY_PAID', 'UNPAID'].includes(seededStatus)
    ? seededStatus
    : paymentStatusFrom({ paid: customerPaid + receiverPaid, due: total });
  return {
    ...order,
    paymentPlan: plan,
    customerResponsibility: customerAmount,
    receiverResponsibility: receiverAmount,
    customerPaid,
    receiverPaid,
    outstandingAmount: round2(total - customerPaid - receiverPaid),
    paymentStatus: overall,
    payment: methodsSummary(allocation) || order.payment,
  };
}

export function buildCreatePaymentPlan({
  totalAmount,
  whoPays = 'customer',
  customerAmount,
  customerMode = 'online',
  receiverMode = 'cash',
  customerOnlineAmount,
  receiverOnlineAmount,
  orderId,
}) {
  const total = round2(totalAmount);
  let customer = total;
  if (whoPays === 'receiver') customer = 0;
  if (whoPays === 'split') customer = round2(customerAmount ?? total / 2);
  if (customer < 0) customer = 0;
  if (customer > total) customer = total;
  const receiver = round2(total - customer);

  const split = (due, requested, mode) => {
    if (due <= 0) return { online: 0, cash: 0 };
    if (mode === 'cash') return { online: 0, cash: due };
    if (mode === 'split') {
      let online = round2(requested ?? due / 2);
      if (online < 0) online = 0;
      if (online > due) online = due;
      return { online, cash: round2(due - online) };
    }
    return { online: due, cash: 0 };
  };

  const customerSplit = split(customer, customerOnlineAmount, customerMode);
  const receiverSplit = split(receiver, receiverOnlineAmount, receiverMode);
  const allocation = {
    customerOnline: customerSplit.online,
    customerCash: customerSplit.cash,
    receiverOnline: receiverSplit.online,
    receiverCash: receiverSplit.cash,
  };
  const error = validatePaymentPlan({
    totalAmount: total,
    customerAmount: customer,
    receiverAmount: receiver,
    allocation,
  });
  return {
    error,
    paymentPlan: {
      totalAmount: total,
      customerResponsibility: customer,
      receiverResponsibility: receiver,
      allocation,
      transactions: plannedTransactions(orderId, allocation),
    },
  };
}
