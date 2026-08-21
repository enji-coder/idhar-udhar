export function round2(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
}

export const DEFAULT_FARE_BY_CATEGORY = {
  Bike: { baseFare: 79, perKmCharge: 0, initialMinimum: 79, waitingCharge: 0, surgeCharge: 0, tollCharge: 0, parkingCharge: 0, weightCapacityKg: 20, size: '36cm' },
  Auto: { baseFare: 149, perKmCharge: 0, initialMinimum: 149, waitingCharge: 0, surgeCharge: 0, tollCharge: 0, parkingCharge: 0, weightCapacityKg: 100, size: '' },
  'Mini Truck': { baseFare: 399, perKmCharge: 0, initialMinimum: 399, waitingCharge: 0, surgeCharge: 0, tollCharge: 0, parkingCharge: 0, weightCapacityKg: 500, size: '' },
  Tempo: { baseFare: 499, perKmCharge: 0, initialMinimum: 499, waitingCharge: 0, surgeCharge: 0, tollCharge: 0, parkingCharge: 0, weightCapacityKg: 900, size: '' },
  'Large Tempo': { baseFare: 599, perKmCharge: 0, initialMinimum: 599, waitingCharge: 0, surgeCharge: 0, tollCharge: 0, parkingCharge: 0, weightCapacityKg: 1500, size: '' },
  Truck: { baseFare: 699, perKmCharge: 0, initialMinimum: 699, waitingCharge: 0, surgeCharge: 0, tollCharge: 0, parkingCharge: 0, weightCapacityKg: 1000, size: '' },
};

export function emptyFareFields() {
  return {
    baseFare: 0,
    perKmCharge: 0,
    initialMinimum: 0,
    waitingCharge: 0,
    surgeCharge: 0,
    tollCharge: 0,
    parkingCharge: 0,
    weightCapacityKg: '',
    size: '',
    fareVersionId: 'fare_v1',
  };
}

/** GST is not applied. */
export function quoteFare(config, distanceKm = 0, discount = 0) {
  const baseFare = Number(config.baseFare || 0);
  const perKmCharge = Number(config.perKmCharge || 0);
  const initialMinimum = Number(config.initialMinimum || 0);
  const waitingCharge = Number(config.waitingCharge || 0);
  const surgeCharge = Number(config.surgeCharge || 0);
  const tollCharge = Number(config.tollCharge || 0);
  const parkingCharge = Number(config.parkingCharge || 0);
  const distanceCharge = round2(perKmCharge * Number(distanceKm || 0));
  const raw = baseFare + distanceCharge + waitingCharge + surgeCharge + tollCharge + parkingCharge;
  const tripFare = raw < initialMinimum ? initialMinimum : round2(raw);
  const afterDiscount = Math.max(0, tripFare - Number(discount || 0));
  const netTotal = round2(afterDiscount);
  return {
    configVersionId: config.fareVersionId || config.versionId || 'fare_v1',
    distanceKm: Number(distanceKm || 0),
    baseFare,
    perKmCharge,
    distanceCharge,
    initialMinimum,
    waitingCharge,
    surgeCharge,
    tollCharge,
    parkingCharge,
    tripFare,
    discount: Number(discount || 0),
    subtotal: netTotal,
    rounding: 0,
    tax: 0,
    netTotal,
    quotedAt: new Date().toISOString(),
  };
}

const fareHistory = [];

export function publishFareVersion(categoryId, config) {
  const version = {
    id: `fare_${categoryId}_${Date.now()}`,
    categoryId,
    ...config,
    effectiveFrom: new Date().toISOString(),
  };
  fareHistory.push(version);
  return version;
}

export function fareHistoryFor(categoryId) {
  return fareHistory.filter((row) => row.categoryId === categoryId);
}
