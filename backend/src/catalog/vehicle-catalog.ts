export const VEHICLE_TYPES = ['two_wheeler', 'three_wheeler', 'truck'] as const;

export const VEHICLES = [
  'bike',
  'scooty',
  'loader_riksha',
  'mini_truck',
  'tempo',
  'large_tempo',
  'truck',
] as const;

export type VehicleType = (typeof VEHICLE_TYPES)[number];
export type VehicleCode = (typeof VEHICLES)[number];

const VEHICLES_FOR_TYPE: Record<VehicleType, readonly VehicleCode[]> = {
  two_wheeler: ['bike', 'scooty'],
  three_wheeler: ['loader_riksha'],
  truck: ['mini_truck', 'tempo', 'large_tempo', 'truck'],
};

export function isVehicleType(value: string): value is VehicleType {
  return (VEHICLE_TYPES as readonly string[]).includes(value);
}

export function isVehicleCode(value: string): value is VehicleCode {
  return (VEHICLES as readonly string[]).includes(value);
}

export function isVehiclePair(vehicleType: string, vehicle: string): boolean {
  if (!isVehicleType(vehicleType) || !isVehicleCode(vehicle)) return false;
  return VEHICLES_FOR_TYPE[vehicleType].includes(vehicle);
}

export function canonicalVehiclePairs(): ReadonlyArray<{
  vehicleType: VehicleType;
  vehicle: VehicleCode;
}> {
  return VEHICLE_TYPES.flatMap((vehicleType) =>
    VEHICLES_FOR_TYPE[vehicleType].map((vehicle) => ({ vehicleType, vehicle })),
  );
}
