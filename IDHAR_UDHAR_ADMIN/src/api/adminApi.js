import { apiDownload, apiRequest, clearTokens, saveTokens } from './client';
import { mapCustomer, mapEarning, mapNotice, mapOrder, mapPayment, mapRider, mapVehicle, mapVehicleCategory, mapZone } from './mappers';

export async function adminLogin(email, password) {
  const tokens = await apiRequest('/v1/admin/auth/login', {
    method: 'POST',
    skipAuth: true,
    body: { email, password },
  });
  saveTokens(tokens);
  return tokens;
}

export async function adminLogout() {
  try {
    await apiRequest('/v1/auth/logout', { method: 'POST' });
  } finally {
    clearTokens();
  }
}

export async function adminSession() {
  return apiRequest('/v1/auth/session');
}

export async function adminProfile() {
  return apiRequest('/v1/admin/profile');
}

export async function fetchAdminOrders() {
  const body = await apiRequest('/v1/admin/orders');
  return (body.orders || []).map(mapOrder);
}

export async function fetchAdminOrder(id) {
  return mapOrder(await apiRequest(`/v1/admin/orders/${id}`));
}

export async function assignAdminOrder(orderId, riderProfileId) {
  return apiRequest(`/v1/admin/orders/${orderId}/assign`, {
    method: 'POST',
    body: { rider_profile_id: riderProfileId },
  });
}

export async function cancelAdminOrder(orderId) {
  return apiRequest(`/v1/admin/orders/${orderId}/cancel`, { method: 'POST' });
}

export async function transitionAdminOrder(orderId, toStatus, reason) {
  return apiRequest(`/v1/admin/orders/${orderId}/status`, {
    method: 'POST',
    body: { to_status: toStatus, ...(reason ? { reason } : {}) },
  });
}

export async function offerAdminOrder(orderId, riderProfileId) {
  return apiRequest(`/v1/admin/orders/${orderId}/offers`, {
    method: 'POST',
    body: { rider_profile_id: riderProfileId },
  });
}

export async function fetchAdminRiders() {
  const body = await apiRequest('/v1/admin/riders');
  return (body.riders || []).map(mapRider);
}

export async function fetchAdminRider(id) {
  return mapRider(await apiRequest(`/v1/admin/riders/${id}`));
}

export async function fetchAdminCustomers() {
  const body = await apiRequest('/v1/admin/customers');
  return (body.customers || []).map((row) => mapCustomer(row));
}

export async function fetchAdminCustomer(id) {
  return mapCustomer(await apiRequest(`/v1/admin/customers/${id}`));
}

export async function fetchAdminPayments() {
  const body = await apiRequest('/v1/admin/payments');
  return (body.transactions || []).map(mapPayment);
}

export async function fetchAdminEarnings() {
  const body = await apiRequest('/v1/admin/earnings');
  return (body.earnings || []).map(mapEarning);
}

export async function fetchRiderWallet(riderId) {
  return apiRequest(`/v1/admin/riders/${riderId}/wallet`);
}

export async function fetchRiderCod(riderId) {
  return apiRequest(`/v1/admin/riders/${riderId}/cod`);
}

export async function fetchRiderWalletLedger(riderId) {
  const body = await apiRequest(`/v1/admin/riders/${riderId}/wallet/ledger`);
  return body.entries || [];
}

export async function fetchAdminNotices() {
  const body = await apiRequest('/v1/notifications?limit=50');
  return (body.notifications || []).map(mapNotice);
}

export async function markNoticeRead(id) {
  return apiRequest(`/v1/notifications/${id}/read`, { method: 'POST' });
}

export async function markAllNoticesRead() {
  return apiRequest('/v1/notifications/read-all', { method: 'POST' });
}

export async function fetchRiderEarnings(riderId) {
  const body = await apiRequest(`/v1/admin/riders/${riderId}/earnings`);
  return (body.earnings || []).map(mapEarning);
}

export async function fetchRiderCodLedger(riderId) {
  const body = await apiRequest(`/v1/admin/riders/${riderId}/cod/ledger`);
  return body.entries || [];
}

export async function fetchAdminVehicleCategories() {
  const body = await apiRequest('/v1/admin/vehicle-categories');
  return (body.vehicle_categories || []).map(mapVehicleCategory);
}

export async function createAdminVehicleCategory(payload) {
  return mapVehicleCategory(await apiRequest('/v1/admin/vehicle-categories', {
    method: 'POST',
    body: payload,
  }));
}

export async function updateAdminVehicleCategory(id, payload) {
  return mapVehicleCategory(await apiRequest(`/v1/admin/vehicle-categories/${id}`, {
    method: 'PATCH',
    body: payload,
  }));
}

export async function deleteAdminVehicleCategory(id) {
  return apiRequest(`/v1/admin/vehicle-categories/${id}`, { method: 'DELETE' });
}

export async function fetchAdminZones() {
  const body = await apiRequest('/v1/admin/zones');
  return (body.zones || []).map(mapZone);
}

export async function createAdminZone(payload) {
  return mapZone(await apiRequest('/v1/admin/zones', { method: 'POST', body: payload }));
}

export async function updateAdminZone(id, payload) {
  return mapZone(await apiRequest(`/v1/admin/zones/${id}`, { method: 'PATCH', body: payload }));
}

export async function deleteAdminZone(id) {
  return apiRequest(`/v1/admin/zones/${id}`, { method: 'DELETE' });
}

export async function fetchAdminVehicles() {
  const body = await apiRequest('/v1/admin/vehicles');
  return (body.vehicles || []).map(mapVehicle);
}

export async function createAdminVehicle(payload) {
  return mapVehicle(await apiRequest('/v1/admin/vehicles', { method: 'POST', body: payload }));
}

export async function updateAdminVehicle(id, payload) {
  return mapVehicle(await apiRequest(`/v1/admin/vehicles/${id}`, { method: 'PATCH', body: payload }));
}

export async function deleteAdminVehicle(id) {
  return apiRequest(`/v1/admin/vehicles/${id}`, { method: 'DELETE' });
}

function gstReportQuery(params = {}) {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value != null && value !== '') search.set(key, String(value));
  });
  return search.toString();
}

/**
 * Every figure here is calculated by the backend from the frozen finance and
 * tax snapshots. The page displays them and never recomputes them.
 */
export async function fetchGstReport(params) {
  return apiRequest(`/v1/admin/reports/gst?${gstReportQuery(params)}`);
}

export async function downloadGstReportExcel(params) {
  return apiDownload(`/v1/admin/reports/gst/export?${gstReportQuery(params)}`, {
    fallbackFilename: 'gst-report.xlsx',
  });
}

export async function fetchTaxConfig() {
  return apiRequest('/v1/admin/tax-config');
}

export async function publishTaxConfig(payload) {
  return apiRequest('/v1/admin/tax-config', { method: 'POST', body: payload });
}
