export type LatLng = {
  latitude: number;
  longitude: number;
};

export class CoordinateError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'CoordinateError';
  }
}

function asFiniteNumber(value: unknown, field: string): number {
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new CoordinateError(`${field} is not a finite number`);
    }
    return value;
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
      throw new CoordinateError(`${field} is not a finite number`);
    }
    return parsed;
  }
  throw new CoordinateError(`${field} is required`);
}

export function assertLatitude(value: unknown): number {
  const latitude = asFiniteNumber(value, 'latitude');
  if (latitude < -90 || latitude > 90) {
    throw new CoordinateError('latitude must be between -90 and 90');
  }
  return latitude;
}

export function assertLongitude(value: unknown): number {
  const longitude = asFiniteNumber(value, 'longitude');
  if (longitude < -180 || longitude > 180) {
    throw new CoordinateError('longitude must be between -180 and 180');
  }
  return longitude;
}

export function assertLatLng(input: {
  latitude: unknown;
  longitude: unknown;
}): LatLng {
  return {
    latitude: assertLatitude(input.latitude),
    longitude: assertLongitude(input.longitude),
  };
}

/** Earth-mean radius in meters. Used only by the mock provider. */
const EARTH_RADIUS_M = 6_371_000;

export function haversineMeters(from: LatLng, to: LatLng): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(to.latitude - from.latitude);
  const dLng = toRad(to.longitude - from.longitude);
  const lat1 = toRad(from.latitude);
  const lat2 = toRad(to.latitude);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_M * c;
}

/**
 * Integer meters → km string with 3 fractional digits (fare NUMERIC(10,3)).
 * Uses integer division so IEEE-754 is not the distance authority.
 */
export function metersToKm(meters: number): string {
  if (!Number.isInteger(meters) || meters <= 0) {
    throw new Error('distance_meters must be a positive integer');
  }
  if (meters > 9_999_999_999) {
    throw new Error('distance_meters exceeds fare snapshot capacity');
  }
  const whole = Math.floor(meters / 1000);
  const frac = meters % 1000;
  return `${whole}.${String(frac).padStart(3, '0')}`;
}
