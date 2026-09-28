import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';

const CAPACITY_KG = /^(\d+(?:\.\d+)?)\s*(kg)?$/i;

/** Kilograms from an admin weight-capacity string such as "20" or "1000 kg". */
export function parseCapacityKg(raw: string | null | undefined): number | null {
  if (raw == null) return null;
  const match = raw.trim().match(CAPACITY_KG);
  if (!match) return null;
  const value = Number(match[1]);
  if (!Number.isFinite(value) || value <= 0) return null;
  return value;
}

function grams(kg: number): number {
  return Math.round(kg * 1000);
}

export function packageExceedsCapacity(
  weightKg: number,
  capacityText: string | null | undefined,
): boolean {
  const capacity = parseCapacityKg(capacityText);
  if (capacity == null) return false;
  return grams(weightKg) > grams(capacity);
}

export function assertPackageForVehicle(input: {
  weightKg: number | null;
  weightCapacity: string | null | undefined;
}): void {
  const capacity = parseCapacityKg(input.weightCapacity);
  if (capacity != null && input.weightKg == null) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'Package weight is required for this vehicle',
      400,
    );
  }
  if (
    input.weightKg != null &&
    packageExceedsCapacity(input.weightKg, input.weightCapacity)
  ) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'Package weight exceeds this vehicle capacity',
      400,
    );
  }
}
