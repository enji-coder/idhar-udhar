import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';

const CAPACITY_KG = /^(\d+(?:\.\d+)?)\s*(kg)?$/i;
const LENGTH_UNIT =
  'mm|cm|m|ft|feet|inches|inch|in';
const SINGLE_SIZE = new RegExp(
  `^(\\d+(?:\\.\\d+)?)\\s*(${LENGTH_UNIT})$`,
  'i',
);
const LABELED_BOX = new RegExp(
  `^(\\d+(?:\\.\\d+)?)\\s*(${LENGTH_UNIT})\\s+long,\\s*` +
    `(\\d+(?:\\.\\d+)?)\\s*(${LENGTH_UNIT})\\s+wide,\\s*` +
    `(\\d+(?:\\.\\d+)?)\\s*(${LENGTH_UNIT})\\s+high$`,
  'i',
);

/** Thousandths of a centimetre for one of that unit. mm is listed before m by the caller. */
const UNIT_THOUSANDTHS_CM: Record<string, number> = {
  mm: 100,
  cm: 1_000,
  m: 100_000,
  ft: 30_480,
  feet: 30_480,
  in: 2_540,
  inch: 2_540,
  inches: 2_540,
};

export type LabeledBoxCm = {
  lengthCm: number;
  widthCm: number;
  heightCm: number;
};

/** Kilograms from an admin weight-capacity string such as "20" or "1000 kg". */
export function parseCapacityKg(raw: string | null | undefined): number | null {
  if (raw == null) return null;
  const match = raw.trim().match(CAPACITY_KG);
  if (!match) return null;
  const value = Number(match[1]);
  if (!Number.isFinite(value) || value <= 0) return null;
  return value;
}

/**
 * Centimetres from one explicit length such as "36 cm" or "8 ft".
 * A missing unit is not treated as centimetres.
 * A length/width/height sentence is not collapsed into one limit.
 */
export function parseSizeCm(raw: string | null | undefined): number | null {
  const thousandths = parseSizeLimitThousandths(raw);
  if (thousandths == null) return null;
  return thousandths / 1000;
}

/** Integer thousandths of a centimetre for a single explicit length. */
export function parseSizeLimitThousandths(
  raw: string | null | undefined,
): number | null {
  if (raw == null) return null;
  const match = raw.trim().match(SINGLE_SIZE);
  if (!match) return null;
  return lengthThousandths(match[1], match[2]);
}

/**
 * Three explicit sides. This does not choose which side limits a parcel,
 * because the booking request carries one centimetre value.
 */
export function parseLabeledBoxCm(
  raw: string | null | undefined,
): LabeledBoxCm | null {
  if (raw == null) return null;
  const match = raw.trim().match(LABELED_BOX);
  if (!match) return null;
  const length = lengthThousandths(match[1], match[2]);
  const width = lengthThousandths(match[3], match[4]);
  const height = lengthThousandths(match[5], match[6]);
  if (length == null || width == null || height == null) return null;
  return {
    lengthCm: length / 1000,
    widthCm: width / 1000,
    heightCm: height / 1000,
  };
}

function lengthThousandths(coefficient: string, unit: string): number | null {
  const perUnit = UNIT_THOUSANDTHS_CM[unit.toLowerCase()];
  if (perUnit == null) return null;
  const parts = /^(\d+)(?:\.(\d+))?$/.exec(coefficient);
  if (!parts) return null;
  const fraction = parts[2] ?? '';
  if (fraction.length > 6) return null;
  const scale = 10 ** fraction.length;
  const numerator =
    Number(parts[1]) * scale + (fraction === '' ? 0 : Number(fraction));
  if (!Number.isSafeInteger(numerator) || numerator <= 0) return null;
  const product = numerator * perUnit;
  if (product % scale !== 0) return null;
  const thousandths = product / scale;
  if (!Number.isSafeInteger(thousandths) || thousandths <= 0) return null;
  return thousandths;
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
  const maxThousandths = parseSizeLimitThousandths(sizeText);
  if (maxThousandths == null) return false;
  if (!Number.isFinite(sizeCm)) return true;
  const parcelThousandths = Math.round(sizeCm * 1000);
  return parcelThousandths > maxThousandths;
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
