import { ROLES, defaultModulesForRole, MODULE_KEYS } from '../config/permissions.js';

const ROLE_LABEL = {
  SUPER_ADMIN: ROLES.SUPER_ADMIN,
  SUB_ADMIN: ROLES.SUB_ADMIN,
  OPERATIONS: ROLES.OPERATIONS,
  FINANCE: ROLES.FINANCE,
  SUPPORT: ROLES.SUPPORT,
  MANAGER: ROLES.MANAGER,
};

const STATUS_LABEL = {
  CREATED: 'Pending',
  SEARCHING: 'Pending',
  OFFERED: 'Pending',
  ASSIGNED: 'Assigned',
  EN_ROUTE_PICKUP: 'Rider Arriving',
  ARRIVED_PICKUP: 'Rider Arriving',
  PICKED_UP: 'Picked Up',
  IN_TRANSIT: 'In Transit',
  NEAR_DROP: 'In Transit',
  DELIVERY_ATTEMPT: 'In Transit',
  DELIVERED: 'Delivered',
  RESEND_COMPLETED: 'Delivered',
  CANCELLED: 'Cancelled',
  RECEIVER_UNAVAILABLE: 'Failed',
  FAILED_DELIVERY: 'Failed',
  PARCEL_AT_COMPANY_OFFICE: 'Parcel At Company Office',
  RESEND_REQUESTED: 'Resend Requested',
  RESEND_IN_PROGRESS: 'Resend Requested',
};

export const UI_TO_CANONICAL = {
  Pending: 'SEARCHING',
  Searching: 'SEARCHING',
  Assigned: 'ASSIGNED',
  Accepted: 'ASSIGNED',
  'Rider Arriving': 'EN_ROUTE_PICKUP',
  'Out for Delivery': 'EN_ROUTE_PICKUP',
  'Picked Up': 'PICKED_UP',
  'In Transit': 'IN_TRANSIT',
  Delivered: 'DELIVERED',
  Cancelled: 'CANCELLED',
  Failed: 'FAILED_DELIVERY',
  'Parcel At Company Office': 'PARCEL_AT_COMPANY_OFFICE',
  'Resend Requested': 'RESEND_REQUESTED',
};

function money(value) {
  const amount = Number(value);
  return Number.isFinite(amount) ? amount : 0;
}

function formatWhen(iso) {
  if (!iso) return '';
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '';
  return date.toLocaleString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit' });
}

export function mapAdminSession(profile) {
  const roleKey = profile?.role || 'SUPER_ADMIN';
  const role = ROLE_LABEL[roleKey] || ROLES.SUPER_ADMIN;
  const email = profile?.email || '';
  const name = email.split('@')[0] || 'Admin';
  const modules = Array.isArray(profile?.modules) && profile.modules.length
    ? profile.modules
    : role === ROLES.SUPER_ADMIN
      ? [...MODULE_KEYS]
      : defaultModulesForRole(role);
  return {
    id: profile?.admin_profile_id,
    authenticated: true,
    email,
    name,
    role,
    initials: name.slice(0, 2).toUpperCase(),
    city: 'Ahmedabad',
    financeAccess: role === ROLES.SUPER_ADMIN || role === ROLES.FINANCE || Boolean(profile?.finance_access),
    payoutApprove: Boolean(profile?.payout_approve) || role === ROLES.SUPER_ADMIN,
    modules,
    status: profile?.active === false ? 'Inactive' : 'Active',
    roleKey,
  };
}

export function mapRider(row) {
  const phone = row.phone_normalized || '';
  const short = String(row.rider_profile_id || '').slice(-4);
  const online = row.online_status === 'ONLINE';
  const approval = row.approval_status || 'PENDING';
  let status = 'Pending';
  if (approval === 'SUSPENDED' || row.cod_operational_status === 'SUSPENDED_FOR_COD') status = 'Offline';
  else if (approval === 'REJECTED') status = 'Pending';
  else if (approval === 'APPROVED') status = online ? 'Active' : 'Offline';
  return {
    id: row.rider_profile_id,
    name: phone ? `Rider ${phone.slice(-4)}` : `Rider ${short}`,
    phone,
    vehicle: '',
    vehicleNumber: '',
    zone: row.zone_name || row.city_code || '—',
    status,
    rating: '—',
    kyc: row.onboarding_kyc_status,
    approval: row.approval_status,
    online: row.online_status,
    codStatus: row.cod_operational_status,
    source: 'api',
  };
}

export function mapCustomer(row, orders = []) {
  const related = Array.isArray(orders) ? orders.filter((order) => order.customerId === row.customer_profile_id) : [];
  const spent = related.reduce((sum, order) => sum + money(order.tripFare || order.amount), 0);
  return {
    id: row.customer_profile_id,
    name: row.display_name || 'Customer',
    email: row.email || '',
    phone: row.phone_normalized || '',
    area: row.city_code || '—',
    status: row.status === 'DEACTIVATED' ? 'Inactive' : 'Active',
    account: row.status === 'DEACTIVATED' ? 'Inactive' : 'Active',
    orders: related.length,
    spent,
    joined: '',
    source: 'api',
  };
}

export function mapOrder(row) {
  const fare = money(row.trip_fare);
  const payable = money(row.net_payable || row.trip_fare);
  const snap = row.finance_snapshot;
  const financeSnapshot = snap
    ? {
        totalAmount: money(snap.trip_fare),
        riderAmount: money(snap.rider_amount),
        companyCommission: money(snap.company_commission_amount),
        operationalCost: money(snap.operational_cost_amount),
        actualProfit: money(snap.profit_amount),
        riderPercentage: money(snap.rider_percentage),
        companyCommissionPercentage: money(snap.company_commission_percentage),
        operationalCostPercentage: money(snap.operational_cost_percentage_of_commission),
      }
    : null;
  return {
    id: row.display_id,
    backendOrderId: row.order_id,
    customerId: row.customer_profile_id,
    customer: row.customer_display_name || row.customer_phone || 'Customer',
    riderId: row.rider_profile_id || '',
    rider: row.rider_phone ? `Rider ${String(row.rider_phone).slice(-4)}` : 'Unassigned',
    pickup: row.pickup_address || '—',
    destination: row.drop_address || '—',
    vehicle: row.vehicle_category_name || '',
    status: STATUS_LABEL[row.canonical_status] || row.canonical_status,
    canonicalStatus: row.canonical_status,
    amount: payable || fare,
    tripFare: fare,
    netPayable: payable,
    payment: '',
    paymentStatus: financeSnapshot ? 'Paid' : 'Pending',
    date: formatWhen(row.created_at),
    time: '',
    lastUpdated: formatWhen(row.updated_at),
    financeSnapshot,
    source: 'api',
  };
}

export function mapPayment(row) {
  const statusMap = {
    PAID: 'Success',
    PENDING: 'Pending',
    FAILED: 'Failed',
    REFUNDED: 'Refunded',
  };
  return {
    id: row.payment_transaction_id,
    backendId: row.payment_transaction_id,
    orderId: row.display_id || row.order_id,
    backendOrderId: row.order_id,
    customer: row.payer_type || '',
    user: row.payer_type,
    method: row.method,
    amount: money(row.amount),
    status: statusMap[row.transaction_status] || row.transaction_status,
    date: formatWhen(row.created_at),
    source: 'api',
  };
}

export function mapEarning(row) {
  return {
    id: row.display_id || row.order_id,
    rider: row.rider_profile_id || 'Rider',
    riderId: row.rider_profile_id,
    orders: 1,
    tripFare: money(row.trip_fare),
    riderEarning: money(row.rider_amount),
    companyCommission: money(row.company_commission_amount),
    operationalExpense: money(row.operational_cost_amount),
    netCompanyEarnings: money(row.profit_amount),
    date: row.frozen_at,
    financeSnapshot: {
      totalAmount: money(row.trip_fare),
      riderAmount: money(row.rider_amount),
      companyCommission: money(row.company_commission_amount),
      operationalCost: money(row.operational_cost_amount),
      actualProfit: money(row.profit_amount),
      riderPercentage: money(row.rider_percentage),
      companyCommissionPercentage: money(row.company_commission_percentage),
    },
    source: 'api',
  };
}

export function mapNotice(row) {
  return {
    id: row.notification_id,
    title: row.title,
    message: row.body,
    time: formatWhen(row.created_at),
    unread: !row.read_at,
    read: Boolean(row.read_at),
    type: row.type,
    category: row.type || 'Notice',
    priority: 'Medium',
  };
}

function moneyOrEmpty(value) {
  if (value == null || value === '') return 0;
  return money(value);
}

export function mapVehicleCategory(row) {
  const rates = row.rates || {};
  const usage = row.usage || {};
  return {
    id: row.vehicle_category_id,
    name: row.name,
    status: row.active === false ? 'Inactive' : 'Active',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    fareVersionId: row.fare_config_version_id || '',
    baseFare: moneyOrEmpty(rates.base_fare),
    perKmCharge: moneyOrEmpty(rates.per_km),
    initialMinimum: moneyOrEmpty(rates.initial_minimum),
    waitingCharge: moneyOrEmpty(rates.waiting),
    surgeCharge: moneyOrEmpty(rates.surge),
    tollCharge: moneyOrEmpty(rates.toll),
    parkingCharge: moneyOrEmpty(rates.parking),
    weightCapacityKg: row.weight_capacity || '',
    size: row.size || '',
    usage: {
      vehicles: Number(usage.vehicles || 0),
      orders: Number(usage.orders || 0),
      riders: 0,
      fareRates: Number(usage.fare_rates || 0),
      total:
        Number(usage.vehicles || 0) +
        Number(usage.orders || 0) +
        Number(usage.fare_quotes || 0) +
        Number(usage.fare_snapshots || 0) +
        Number(usage.fare_rates || 0),
    },
    source: 'api',
  };
}

export function mapZone(row) {
  return {
    id: row.zone_id,
    name: row.name,
    area: row.city_name || row.city_code || '',
    activeRiders: Number(row.rider_count || 0),
    orders: 0,
    status: row.active === false ? 'Inactive' : 'Active',
    cityId: row.city_id,
    createdAt: row.created_at,
    source: 'api',
  };
}

export function mapVehicle(row) {
  const subtype = row.two_wheeler_subtype === 'SCOOTER' ? 'Scooter' : row.two_wheeler_subtype === 'BIKE' ? 'Bike' : '';
  return {
    id: row.vehicle_id,
    number: row.registration || '',
    rcNumber: row.registration || '',
    type: row.category_name || '',
    category: row.category_name || '',
    categoryId: row.vehicle_category_id,
    twoWheelerType: subtype,
    brand: '',
    model: '',
    variant: '',
    color: '',
    rider: row.rider_phone ? `Rider ${String(row.rider_phone).slice(-4)}` : 'Unassigned',
    riderId: row.rider_profile_id || '',
    status: row.active === false ? 'Inactive' : 'Active',
    capacity: '',
    registered: formatWhen(row.created_at),
    lastService: '',
    insurance: '',
    source: 'api',
  };
}
