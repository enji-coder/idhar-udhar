export const VEHICLE_TYPES = [
  { id: 'two_wheeler', label: 'Two Wheeler' },
  { id: 'three_wheeler', label: 'Three Wheeler' },
  { id: 'truck', label: 'Truck' },
];

export const VEHICLES = [
  { id: 'bike', label: 'Bike', vehicleType: 'two_wheeler' },
  { id: 'scooty', label: 'Scooty', vehicleType: 'two_wheeler' },
  { id: 'loader_riksha', label: 'Loader Riksha', vehicleType: 'three_wheeler' },
  { id: 'mini_truck', label: 'Mini Truck', vehicleType: 'truck' },
  { id: 'tempo', label: 'Tempo', vehicleType: 'truck' },
  { id: 'large_tempo', label: 'Large Tempo', vehicleType: 'truck' },
  { id: 'truck', label: 'Truck', vehicleType: 'truck' },
];

const MONEY_FIELDS = [
  ['baseFare', 'Base fare'],
  ['perKmCharge', 'Per KM charge'],
  ['initialMinimum', 'Initial minimum'],
  ['waitingCharge', 'Waiting charge'],
  ['surgeCharge', 'Surge charge'],
  ['tollCharge', 'Toll charge'],
  ['parkingCharge', 'Parking charge'],
];

export function vehicleTypeLabel(id) {
  return VEHICLE_TYPES.find((item) => item.id === id)?.label || '';
}

export function vehicleLabel(id) {
  return VEHICLES.find((item) => item.id === id)?.label || '';
}

export function vehiclesForType(vehicleType) {
  return VEHICLES.filter((item) => item.vehicleType === vehicleType);
}

export function isVehiclePair(vehicleType, vehicle) {
  return VEHICLES.some((item) => item.id === vehicle && item.vehicleType === vehicleType);
}

export function compatibleVehicle(vehicleType, vehicle) {
  return isVehiclePair(vehicleType, vehicle) ? vehicle : '';
}

function normalizeName(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

export function issuesForVehicleCategoryForm(form, rows = []) {
  const issues = {};
  const vehicleType = String(form.vehicleType || '').trim();
  const vehicle = String(form.vehicle || '').trim();
  const knownType = VEHICLE_TYPES.some((item) => item.id === vehicleType);

  if (!vehicleType) issues.vehicleType = 'Vehicle type is required.';
  else if (!knownType) issues.vehicleType = 'Select a supported vehicle type.';

  if (knownType && !vehicle) issues.vehicle = 'Vehicle is required.';
  else if (knownType && vehicle && !isVehiclePair(vehicleType, vehicle)) {
    issues.vehicle = 'This vehicle does not belong to the selected vehicle type.';
  }

  const name = isVehiclePair(vehicleType, vehicle) ? vehicleLabel(vehicle) : '';
  if (
    name &&
    rows.find((row) => row.id !== form.id && normalizeName(row.name).toLowerCase() === name.toLowerCase())
  ) {
    issues.vehicle = 'This vehicle category already exists.';
  }

  const rider = Number(form.riderSharePercent);
  const company = Number(form.companyCommissionPercent);
  if (!Number.isFinite(rider) || rider < 0) issues.riderSharePercent = 'Rider percentage must be 0 or more.';
  if (!Number.isFinite(company) || company < 0) issues.companyCommissionPercent = 'Company commission must be 0 or more.';
  if (Number.isFinite(rider) && Number.isFinite(company) && Math.round((rider + company) * 100) !== 10000) {
    issues.companyCommissionPercent = 'Rider percentage and company commission must add up to 100%.';
  }

  for (const [key, label] of MONEY_FIELDS) {
    const raw = form[key];
    if (raw === '' || raw == null) continue;
    const amount = Number(raw);
    if (!Number.isFinite(amount) || amount < 0) issues[key] = `${label} must be 0 or more.`;
  }

  const weight = String(form.weightCapacityKg ?? '').trim();
  if (weight && /^-?\d+(\.\d+)?$/.test(weight) && Number(weight) < 0) {
    issues.weightCapacityKg = 'Weight capacity must be 0 or more.';
  }

  return { name, vehicleType, vehicle, issues };
}
