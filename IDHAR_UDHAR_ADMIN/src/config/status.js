export const NA = 'N/A';
export const NOT_ASSIGNED = 'Not Assigned';
export const NOT_AVAILABLE = 'Not Available';

export const PAYMENT_MODES = ['UPI', 'Cash', 'Card', 'Net Banking', 'Wallet'];

export const PAYMENT_STATUSES = ['Paid', 'Pending', 'Refunded', 'Failed'];

export const DELIVERY_REPORT_STATUSES = [
  'Delivery Pending',
  'In-Transit',
  'Out for Delivery',
  'Delivered',
  'Failed / Returned',
];

export const ORDER_STATUSES = [
  'Pending',
  'Assigned',
  'Rider Arriving',
  'Out for Delivery',
  'Picked Up',
  'In Transit',
  'Delivered',
  'Cancelled',
  'Failed',
  'Parcel At Company Office',
  'Resend Requested',
];

export const CUSTOMER_CATEGORIES = ['New', 'Active', 'Repeat', 'Inactive'];

export const CANCELLED_BY = ['Customer', 'Rider', 'Admin'];

export const PAYOUT_STATUSES = ['Pending', 'Approved', 'Paid', 'Rejected'];

export const DOCUMENT_ALERT_STATUSES = ['Valid', 'Expiring Soon', 'Expired'];

export { DEFAULT_VEHICLE_CATEGORY_NAMES as VEHICLE_CATEGORIES } from '../data/vehicleCategories';

export const TWO_WHEELER_TYPES = ['Bike', 'Scooter'];

const DELIVERY_STATUS_MAP = {
  Pending: 'Delivery Pending',
  Searching: 'Delivery Pending',
  Assigned: 'Delivery Pending',
  Accepted: 'Delivery Pending',
  'Rider Arriving': 'Out for Delivery',
  'Out for Delivery': 'Out for Delivery',
  'Picked Up': 'In-Transit',
  'In Transit': 'In-Transit',
  Delivered: 'Delivered',
  Failed: 'Failed / Returned',
  Returned: 'Failed / Returned',
};

export function toDeliveryReportStatus(status) {
  if (!status || status === 'Cancelled') return status || NA;
  return DELIVERY_STATUS_MAP[status] || status;
}

export function displayValue(value, fallback = NA) {
  if (value == null || value === '') return fallback;
  const text = String(value).trim();
  if (!text || text === 'Unassigned' || text === 'undefined' || text === 'null') return fallback;
  return text;
}

export function displayRider(value) {
  return displayValue(value, NOT_ASSIGNED);
}
