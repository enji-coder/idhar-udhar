import { displayRider, displayValue, NA, NOT_AVAILABLE, PAYMENT_MODES, toDeliveryReportStatus } from '../config/status';
import { calculateOrderFinance } from './commission';
import { classifyCustomer, categoryLabel } from './customerClassification';
import { enrichCustomerProfile, enrichRiderProfile, enrichVehicleRecord } from './profileEnrichment';
import { formatAppDate, formatAppTime, formatTimestamp, inDateRange, parseAppDate } from '../utils/dates';
import { formatNumericOrderId, invoiceNumberFor, withStableOrderId } from '../utils/orderId';
import { maskAadhaar } from '../utils/masking';

function indexBy(rows, keys) {
  const map = {};
  rows.forEach((row) => {
    keys.forEach((key) => {
      const value = row[key];
      if (value != null && value !== '') map[String(value)] = row;
    });
  });
  return map;
}

function pincodeOf(text) {
  const match = String(text || '').match(/\b(\d{6})\b/);
  return match ? match[1] : NA;
}

function cancelledByOf(order) {
  if (order.cancelledBy) return order.cancelledBy;
  const reason = `${order.cancelReason || ''}`.toLowerCase();
  if (reason.includes('admin')) return 'Admin';
  if (reason.includes('rider')) return 'Rider';
  if (reason.includes('customer') || order.status === 'Cancelled') return 'Customer';
  return NA;
}

function normalizePaymentMode(value) {
  const text = String(value || '').trim();
  if (PAYMENT_MODES.includes(text)) return text;
  if (/net.?bank/i.test(text) || text === 'Online') return 'Net Banking';
  if (/upi/i.test(text)) return 'UPI';
  if (/cash/i.test(text)) return 'Cash';
  if (/card/i.test(text)) return 'Card';
  if (/wallet/i.test(text)) return 'Wallet';
  return text || NA;
}

function paymentStatusOf(order, payment) {
  if (payment?.status === 'Success') return 'Paid';
  if (payment?.status === 'Pending') return 'Pending';
  if (payment?.status === 'Refunded') return 'Refunded';
  if (payment?.status === 'Failed') return 'Failed';
  return order.paymentStatus || NA;
}

function gatewayStatusOf(order, payment) {
  const mode = normalizePaymentMode(payment?.method || order.payment);
  if (mode === 'Cash') return 'Cash Collection';
  if (payment?.gatewayStatus) return payment.gatewayStatus;
  if (payment?.status === 'Success') return 'Success';
  if (payment?.status === 'Failed') return 'Failed';
  if (payment?.status === 'Pending') return 'Pending';
  if (order.paymentStatus === 'Paid') return 'Success';
  return order.paymentStatus || NA;
}

export function buildLookupMaps({ riders = [], customers = [], payments = [], vehicles = [], invoices = [], payouts = [] }) {
  return {
    riderById: indexBy(riders, ['id']),
    riderByName: indexBy(riders, ['name']),
    customerById: indexBy(customers, ['id']),
    customerByName: indexBy(customers, ['name']),
    paymentByOrder: indexBy(payments, ['orderId']),
    invoiceByOrder: indexBy(invoices, ['orderId']),
    vehicleByNumber: indexBy(vehicles, ['number', 'rcNumber']),
    vehicleByRider: indexBy(vehicles.filter((row) => row.riderId), ['riderId']),
    payoutByRider: indexBy(payouts, ['riderId', 'rider']),
  };
}

export function joinOrder(order, maps, allOrders = []) {
  const base = withStableOrderId(order);
  const customer = enrichCustomerProfile(maps.customerById[base.customerId] || maps.customerByName[base.customer] || {
    name: base.customer,
    phone: base.customerPhone,
    email: base.customerEmail,
  });
  const riderRaw = base.riderId ? maps.riderById[base.riderId] : maps.riderByName[base.rider];
  const rider = riderRaw ? enrichRiderProfile(riderRaw) : null;
  const vehicleRaw = maps.vehicleByNumber[base.vehicleNumber] || (base.riderId ? maps.vehicleByRider[base.riderId] : null);
  const vehicle = vehicleRaw ? enrichVehicleRecord(vehicleRaw, riderRaw) : enrichVehicleRecord({
    number: base.vehicleNumber,
    type: base.vehicle,
    rider: base.rider,
    riderId: base.riderId,
  }, riderRaw);
  const payment = maps.paymentByOrder[base.id] || maps.paymentByOrder[formatNumericOrderId(base.orderId)];
  const invoice = maps.invoiceByOrder[base.id];
  const finance = calculateOrderFinance(base);
  const category = classifyCustomer(customer, allOrders);
  const cancelled = base.status === 'Cancelled';
  return {
    ...base,
    orderId: formatNumericOrderId(base.orderId),
    orderCode: base.id,
    invoiceNumber: invoice?.invoiceNumber || invoiceNumberFor(base),
    customerName: displayValue(customer.name || base.customer),
    customerPhone: displayValue(customer.phone || base.customerPhone),
    customerEmail: displayValue(customer.email || base.customerEmail),
    customerCategory: category,
    customerCategoryLabel: categoryLabel(category),
    customerOnboardingDate: customer.onboardingDate,
    customerLocation: customer.location,
    customerPincode: customer.pincode,
    riderName: displayRider(rider?.name || base.rider),
    riderPhone: rider ? displayValue(rider.phone || base.riderPhone) : NOT_AVAILABLE,
    riderEmail: rider ? displayValue(rider.email) : NOT_AVAILABLE,
    riderAddress: rider ? displayValue(rider.address) : NOT_AVAILABLE,
    riderPincode: rider ? displayValue(rider.pincode) : NOT_AVAILABLE,
    riderEmergency: rider ? displayValue(rider.emergencyContact) : NOT_AVAILABLE,
    riderOnboardingDate: rider ? displayValue(rider.onboardingDate) : NOT_AVAILABLE,
    drivingLicenseNumber: rider ? displayValue(rider.drivingLicenseNumber) : NOT_AVAILABLE,
    aadhaarNumber: rider?.aadhaarNumber || '',
    aadhaarMasked: rider ? maskAadhaar(rider.aadhaarNumber) : NOT_AVAILABLE,
    panNumber: rider ? displayValue(rider.panMasked) : NOT_AVAILABLE,
    bankAccountNumber: rider ? displayValue(rider.bankMasked) : NOT_AVAILABLE,
    ifscCode: rider ? displayValue(rider.ifscMasked) : NOT_AVAILABLE,
    rcNumber: displayValue(vehicle.rcNumber || rider?.rcNumber || base.vehicleNumber),
    vehicleCategory: displayValue(vehicle.category || base.vehicle),
    vehicleBrand: displayValue(vehicle.brand),
    vehicleModel: displayValue(vehicle.model),
    vehicleVariant: displayValue(vehicle.variant),
    vehicleColor: displayValue(vehicle.color),
    twoWheelerType: displayValue(vehicle.twoWheelerType, ''),
    pickupLocation: displayValue(base.pickup),
    dropLocation: displayValue(base.destination),
    pickupPincode: pincodeOf(base.pickupAddress || base.pickup),
    dropPincode: pincodeOf(base.destinationAddress || base.destination),
    goodsDetails: displayValue(base.packageType),
    goodsWeight: displayValue(base.weight),
    orderStatus: displayValue(base.status),
    deliveryStatus: toDeliveryReportStatus(base.status),
    paymentAmount: finance.customerPayment,
    paymentMode: normalizePaymentMode(payment?.method || base.payment),
    paymentStatus: paymentStatusOf(base, payment),
    paymentGatewayStatus: gatewayStatusOf(base, payment),
    cashCollection: normalizePaymentMode(payment?.method || base.payment) === 'Cash' ? finance.customerPayment : 0,
    paymentDate: displayValue(payment?.date || base.date),
    transactionId: displayValue(payment?.id, `TXN-${formatNumericOrderId(base.orderId)}`),
    ...finance,
    revenueDate: displayValue(base.date),
    orderDate: displayValue(base.date),
    orderTime: displayValue(base.time),
    cancellationDate: cancelled ? formatAppDate(parseAppDate(base.cancelledAt || base.date)) : NA,
    cancellationTime: cancelled ? formatAppTime(base.cancelledAt || base.time) : NA,
    cancellationTimestamp: cancelled ? formatTimestamp(base.cancelledAt || base.date, base.cancelledAt || base.time) : NA,
    cancellationReason: cancelled ? displayValue(base.cancelReason, NOT_AVAILABLE) : NA,
    cancelledBy: cancelled ? cancelledByOf(base) : NA,
    customerRatingByRider: base.customerRating ?? (base.status === 'Delivered' ? 5 : NA),
    riderRatingByCustomer: base.riderRating ?? (base.status === 'Delivered' ? rider?.rating || NA : NA),
  };
}

export function joinOrders(sources) {
  const maps = buildLookupMaps(sources);
  return (sources.orders || []).map((order) => joinOrder(order, maps, sources.orders));
}

export function filterByDate(rows, from, to, field = 'orderDate') {
  if (!from && !to) return rows;
  return rows.filter((row) => inDateRange(row[field] || row.date || row.paymentDate || row.revenueDate, from, to));
}

export function searchRows(rows, query, keys) {
  const value = String(query || '').trim().toLowerCase();
  if (!value) return rows;
  return rows.filter((row) => keys.some((key) => String(row[key] ?? '').toLowerCase().includes(value)));
}
