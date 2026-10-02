import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';

const CAPACITY_KG = /^(\d+(?:\.\d+)?)\s*(kg)?$/i;
const SIZE_CM = /(\d+(?:\.\d+)?)\s*(cm)?/i;

/** Kilograms from an admin weight-capacity string such as "20" or "1000 kg". */
export function parseCapacityKg(raw: string | null | undefined): number | null {
  if (raw == null) return null;
  const match = raw.trim().match(CAPACITY_KG);
  if (!match) return null;
  const value = Number(match[1]);
  if (!Number.isFinite(value) || value <= 0) return null;
  return value;
}

/** Centimetres from an admin size string such as "36cm" or "36". */
export function parseSizeCm(raw: string | null | undefined): number | null {
  if (raw == null) return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  const match = trimmed.match(SIZE_CM);
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

export function packageExceedsSize(
  sizeCm: number,
  sizeText: string | null | undefined,
): boolean {
  const maxCm = parseSizeCm(sizeText);
  if (maxCm == null) return false;
  return sizeCm > maxCm + 0.0001;
}

export function assertPackageForVehicle(input: {
  weightKg: number | null;
  weightCapacity: string | null | undefined;
  packageSizeCm?: number | null;
  sizeLimit?: string | null | undefined;
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
  const maxCm = parseSizeCm(input.sizeLimit);
  if (maxCm != null) {
    if (input.packageSizeCm == null) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Package size is required for this vehicle',
        400,
      );
    }
    if (packageExceedsSize(input.packageSizeCm, input.sizeLimit)) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Package size exceeds this vehicle limit',
        400,
      );
    }
  }
}

/** 10-digit local mobile (strips +91 / non-digits). */
export function normalizeContactPhone(raw: string | null | undefined): string | null {
  if (raw == null) return null;
  const digits = raw.replace(/\D/g, '');
  if (digits.length === 10) return digits;
  if (digits.length > 10) return digits.slice(-10);
  return null;
}

export function assertDropContact(input: {
  contactName?: string | null;
  contactPhone?: string | null;
}): void {
  const name = (input.contactName ?? '').trim();
  if (!name) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'Receiver name is required for each drop',
      400,
    );
  }
  const phone = normalizeContactPhone(input.contactPhone);
  if (!phone || !/^\d{10}$/.test(phone)) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'Receiver mobile must be a valid 10-digit number',
      400,
    );
  }
}
