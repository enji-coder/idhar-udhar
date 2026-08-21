import { ORDER_STATUSES } from '../config/status';
import { numericOrderId } from '../utils/orderId';
import { attachPaymentPlan } from './paymentPlan';

export { ORDER_STATUSES };
export { toDeliveryReportStatus, DELIVERY_REPORT_STATUSES } from '../config/status';

export const CANCEL_REASONS = [
  'Customer Request',
  'Rider Issue',
  'Operational Issue',
  'Payment Issue',
  'Other',
];

export const TIMELINE_STEPS = [
  'Order Created',
  'Rider Assigned',
  'Rider Arrived',
  'Package Picked Up',
  'In Transit',
  'Delivered',
];

const TERMINAL = new Set(['Delivered', 'Cancelled', 'Failed']);

function statusIndex(status) {
  switch (status) {
    case 'Pending':
    case 'Searching':
      return 0;
    case 'Assigned':
    case 'Accepted':
      return 1;
    case 'Out for Delivery':
    case 'Rider Arriving':
      return 2;
    case 'Picked Up':
      return 3;
    case 'In Transit':
      return 4;
    case 'Delivered':
      return 5;
    case 'Cancelled':
    case 'Failed':
      return -1;
    default:
      return 0;
  }
}

export function getOrderActions(order) {
  const status = order?.status;
  const terminal = TERMINAL.has(status);
  const delivered = status === 'Delivered';
  const failed = status === 'Failed';
  const cancelled = status === 'Cancelled';
  const pending = status === 'Pending' || status === 'Searching';
  const hasRider = Boolean(order?.rider && order.rider !== 'Unassigned');

  return {
    view: true,
    track: !cancelled && !failed && !pending && !delivered,
    edit: !terminal,
    reassign: !terminal,
    assign: !terminal && !hasRider,
    invoice: true,
    cancel: !terminal,
    refund: delivered,
    proof: delivered,
    timeline: true,
  };
}

export function buildTimeline(order) {
  if (order?.status === 'Cancelled' || order?.status === 'Failed') {
    return [
      { label: 'Order Created', done: true, current: false, time: order.time || '—' },
      { label: order.status === 'Failed' ? 'Delivery Failed' : 'Cancelled', done: true, current: true, time: order.time || '—' },
    ];
  }

  const current = statusIndex(order?.status);
  return TIMELINE_STEPS.map((label, index) => ({
    label,
    done: index <= current,
    current: index === current,
    time: index <= current ? shiftTime(order?.time, index) : null,
  }));
}

function shiftTime(time, index) {
  if (!time) return null;
  const match = String(time).match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
  if (!match) return time;
  let hours = Number(match[1]);
  const minutes = Number(match[2]);
  const meridiem = match[3].toUpperCase();
  if (meridiem === 'PM' && hours !== 12) hours += 12;
  if (meridiem === 'AM' && hours === 12) hours = 0;
  const date = new Date(2026, 7, 14, hours, minutes + index * 8, 0);
  const h = date.getHours();
  const m = String(date.getMinutes()).padStart(2, '0');
  const suffix = h >= 12 ? 'PM' : 'AM';
  const display = h % 12 || 12;
  return `${display}:${m} ${suffix}`;
}

export function normalizeOrder(order, customers = [], riders = []) {
  if (!order) return order;
  const customer = customers.find((item) => item.id === order.customerId || item.name === order.customer);
  const rider = riders.find((item) => item.id === order.riderId || item.name === order.rider);
  const base = {
    packageType: 'Package',
    weight: '5 KG',
    quantity: 1,
    instructions: '',
    paymentStatus: order.paymentStatus || 'UNPAID',
    time: '11:00 AM',
    pickupAddress: order.pickup,
    destinationAddress: order.destination,
    ...order,
    customerPhone: order.customerPhone || customer?.phone || '',
    customerEmail: order.customerEmail || customer?.email || '',
    vehicleNumber: order.vehicleNumber || rider?.vehicleNumber || '',
    vehicle: order.vehicle || rider?.vehicle || 'Bike',
    lastUpdated: order.lastUpdated || `${order.date || '14 Aug 2026'} ${order.time || '11:00 AM'}`,
    riderPhone: order.riderPhone || rider?.phone || '',
    riderRating: order.riderRating ?? rider?.rating,
    riderStatus: order.riderStatus || rider?.status,
    cancelledBy: order.cancelledBy || (order.status === 'Cancelled' ? 'Customer' : undefined),
    cancelledAt: order.cancelledAt,
    orderId: numericOrderId(order.orderId || order.id),
    dimensions: order.dimensions || (String(order.packageType || '').toLowerCase().includes('document') ? 'A4 envelope' : '30 × 20 × 10 cm'),
    discount: order.discount ?? 0,
  };
  return attachPaymentPlan(base);
}

export function canEditOrder(order) {
  return getOrderActions(order).edit;
}

export function validateOrderEdits(values) {
  const errors = {};
  if (!values.pickup?.trim() || values.pickup.trim().length < 4) errors.pickup = 'Enter a valid pickup location.';
  if (!values.destination?.trim() || values.destination.trim().length < 4) errors.destination = 'Enter a valid destination.';
  if (!values.packageType?.trim()) errors.packageType = 'Select a package type.';
  if (!values.weight?.trim()) errors.weight = 'Enter package weight.';
  const qty = Number(values.quantity);
  if (!qty || qty < 1) errors.quantity = 'Quantity must be at least 1.';
  return errors;
}
