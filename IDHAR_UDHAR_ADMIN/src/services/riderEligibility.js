const ELIGIBLE_STATUSES = new Set(['Active', 'Available', 'Busy']);

const INELIGIBLE_STATUSES = new Set([
  'Offline',
  'Suspended',
  'Rejected',
  'Deactivated',
  'Pending',
  'Inactive',
  'Logged Out',
]);

const INELIGIBLE_VERIFICATION = new Set(['Pending', 'Rejected', 'Correction', 'Pending Verification']);

export function riderDutyLabel(rider) {
  if (!rider) return 'Unassigned';
  if (rider.status === 'Active' || rider.status === 'Available') return 'Available';
  return rider.status;
}

export function isRiderEligible(rider, { allowBusy = true } = {}) {
  if (!rider) return false;
  if (INELIGIBLE_VERIFICATION.has(rider.verification)) return false;
  if (INELIGIBLE_STATUSES.has(rider.status)) return false;
  if (rider.status === 'Busy') return allowBusy;
  return ELIGIBLE_STATUSES.has(rider.status);
}

export function getEligibleRiders(riders, options = {}) {
  return (riders || []).filter((rider) => isRiderEligible(rider, options));
}

export function groupEligibleRiders(riders, options = {}) {
  const eligible = getEligibleRiders(riders, options);
  return {
    available: eligible.filter((rider) => riderDutyLabel(rider) === 'Available'),
    busy: eligible.filter((rider) => rider.status === 'Busy'),
  };
}

export function searchRiders(riders, query = '') {
  const needle = query.trim().toLowerCase();
  if (!needle) return riders;
  return riders.filter((rider) =>
    `${rider.name} ${rider.phone} ${rider.vehicle} ${rider.vehicleNumber || ''} ${rider.zone || ''} ${rider.id}`
      .toLowerCase()
      .includes(needle),
  );
}

export function estimatePickupDistance(rider, order) {
  if (!rider || !order) return null;
  if (rider.distanceKm != null) return rider.distanceKm;
  const zone = (rider.zone || '').toLowerCase();
  const pickup = `${order.pickup || ''}`.toLowerCase();
  if (zone && pickup.includes(zone.toLowerCase())) return 1.2;
  const hash = [...`${rider.id}${order.id}`].reduce((sum, char) => sum + char.charCodeAt(0), 0);
  return Number((2.1 + (hash % 70) / 10).toFixed(1));
}

export function countActiveAssignments(orders, riderId) {
  const live = new Set(['Assigned', 'Accepted', 'Rider Arriving', 'Picked Up', 'In Transit', 'Pending']);
  return (orders || []).filter((order) => order.riderId === riderId && live.has(order.status)).length;
}
