import { DOCUMENT_ALERT_STATUSES } from '../config/status';
import { DATA_TODAY, daysBetween, parseAppDate } from '../utils/dates';
import { displayValue } from '../config/status';

export const DEFAULT_EXPIRY_WINDOW_DAYS = 30;

export function documentStatus(expiryDate, windowDays = DEFAULT_EXPIRY_WINDOW_DAYS, today = DATA_TODAY) {
  const remaining = daysBetween(expiryDate, today);
  if (remaining == null) return { status: 'N/A', daysRemaining: 'N/A' };
  if (remaining < 0) return { status: DOCUMENT_ALERT_STATUSES[2], daysRemaining: remaining };
  if (remaining <= Number(windowDays || DEFAULT_EXPIRY_WINDOW_DAYS)) {
    return { status: DOCUMENT_ALERT_STATUSES[1], daysRemaining: remaining };
  }
  return { status: DOCUMENT_ALERT_STATUSES[0], daysRemaining: remaining };
}

export function buildDocumentAlerts({ riders = [], vehicles = [] }, windowDays = DEFAULT_EXPIRY_WINDOW_DAYS) {
  const rows = [];
  riders.forEach((rider) => {
    if (rider.licenseExpiry) {
      const meta = documentStatus(rider.licenseExpiry, windowDays);
      rows.push({
        id: `${rider.id}-dl`,
        document: 'Driving License',
        rider: rider.name,
        riderId: rider.id,
        vehicle: displayValue(rider.vehicleNumber || rider.vehicle, 'N/A'),
        expiryDate: rider.licenseExpiry,
        ...meta,
      });
    }
  });
  vehicles.forEach((vehicle) => {
    const rider = displayValue(vehicle.rider, 'Not Assigned');
    if (vehicle.rcExpiry) {
      const meta = documentStatus(vehicle.rcExpiry, windowDays);
      rows.push({
        id: `${vehicle.id}-rc`,
        document: 'Vehicle RC',
        rider,
        riderId: vehicle.riderId || '',
        vehicle: vehicle.rcNumber || vehicle.number,
        expiryDate: vehicle.rcExpiry,
        ...meta,
      });
    }
    if (vehicle.insuranceExpiry) {
      const meta = documentStatus(vehicle.insuranceExpiry, windowDays);
      rows.push({
        id: `${vehicle.id}-ins`,
        document: 'Vehicle Insurance',
        rider,
        riderId: vehicle.riderId || '',
        vehicle: vehicle.rcNumber || vehicle.number,
        expiryDate: vehicle.insuranceExpiry,
        ...meta,
      });
    }
  });
  return rows.sort((a, b) => {
    const left = parseAppDate(a.expiryDate)?.getTime() || 0;
    const right = parseAppDate(b.expiryDate)?.getTime() || 0;
    return left - right;
  });
}
