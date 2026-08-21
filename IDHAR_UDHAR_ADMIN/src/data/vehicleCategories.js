export const VEHICLE_CATEGORY_STATUSES = ['Active', 'Inactive'];

export const DEFAULT_VEHICLE_CATEGORY_NAMES = [
  'Bike',
  'Auto',
  'Mini Truck',
  'Tempo',
  'Large Tempo',
  'Truck',
];

export const defaultVehicleCategories = DEFAULT_VEHICLE_CATEGORY_NAMES.map((name, index) => ({
  id: `VC-${String(index + 1001).padStart(4, '0')}`,
  name,
  status: 'Active',
  createdAt: '2026-01-12T09:00:00.000Z',
  updatedAt: '2026-01-12T09:00:00.000Z',
  fareVersionId: `fare_VC-${String(index + 1001).padStart(4, '0')}_v1`,
  baseFare: name === 'Bike' ? 79 : name === 'Auto' ? 149 : name === 'Mini Truck' ? 399 : name === 'Tempo' ? 499 : name === 'Large Tempo' ? 599 : 699,
  perKmCharge: 0,
  initialMinimum: name === 'Bike' ? 79 : name === 'Auto' ? 149 : name === 'Mini Truck' ? 399 : name === 'Tempo' ? 499 : name === 'Large Tempo' ? 599 : 699,
  waitingCharge: 0,
  surgeCharge: 0,
  tollCharge: 0,
  parkingCharge: 0,
  weightCapacityKg: name === 'Bike' ? 20 : name === 'Auto' ? 100 : 1000,
  size: name === 'Bike' ? '36cm' : '',
}));
