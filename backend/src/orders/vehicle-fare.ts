import { isVehiclePair } from '../catalog/vehicle-catalog';
import { formatInr } from '../fare/money';
import { parseCapacityKg } from './package-constraints';

export type VehicleFarePreviewRow = {
  vehicle_category_id: string;
  name: string;
  vehicle_type: string | null;
  vehicle: string | null;
  active: boolean;
  weight_capacity: string | null;
  size: string | null;
  fare_config_version_id: string;
  base_fare: string;
  distance_charge: string;
  waiting: string;
  surge: string;
  toll: string;
  parking: string;
  initial_waiting_minutes?: number;
  waiting_charge_per_minute?: string;
  trip_fare: string;
  discount: string;
  rounding: string;
  net_payable: string;
  tax: string;
};

export function isCustomerBookableVehicle(row: {
  active: boolean;
  vehicle_type: string | null;
  vehicle: string | null;
}): boolean {
  if (!row.active || !row.vehicle_type || !row.vehicle) return false;
  return isVehiclePair(row.vehicle_type, row.vehicle);
}

/** Customer fare lines only. Commission and GST are not part of this payload. */
export function serializeCustomerVehicleFare(row: VehicleFarePreviewRow) {
  const tax = formatInr(row.tax);
  if (tax !== '0.00') {
    throw new Error('Customer vehicle fare tax must be 0');
  }
  const capacityKg = parseCapacityKg(row.weight_capacity);
  return {
    vehicle_category_id: row.vehicle_category_id,
    name: row.name,
    vehicle_type: row.vehicle_type,
    vehicle: row.vehicle,
    active: true,
    weight_capacity: row.weight_capacity,
    weight_capacity_kg: capacityKg == null ? null : capacityKg.toFixed(3),
    size: row.size,
    fare: {
      fare_config_version_id: row.fare_config_version_id,
      base_fare: formatInr(row.base_fare),
      distance_charge: formatInr(row.distance_charge),
      waiting: formatInr(row.waiting),
      surge: formatInr(row.surge),
      toll: formatInr(row.toll),
      parking: formatInr(row.parking),
      initial_waiting_minutes: row.initial_waiting_minutes ?? 0,
      waiting_charge_per_minute: formatInr(row.waiting_charge_per_minute ?? '0'),
      discount: formatInr(row.discount),
      rounding: formatInr(row.rounding),
      trip_fare: formatInr(row.trip_fare),
      net_payable: formatInr(row.net_payable),
      tax,
    },
  };
}

export function faresByVehicle(
  rows: VehicleFarePreviewRow[],
): Map<string, string> {
  const fares = new Map<string, string>();
  for (const row of rows) {
    if (!isCustomerBookableVehicle(row)) continue;
    fares.set(row.vehicle_category_id, formatInr(row.trip_fare));
  }
  return fares;
}
