import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';

/**
 * Report day boundaries.
 *
 * All financial timestamps are TIMESTAMPTZ, so "01-Aug" is only meaningful
 * against a stated zone. The report zone is explicit and is echoed in every
 * response and export so a figure can always be reproduced.
 *
 * Ranges are half-open [from, to): a custom range of 01-Aug to 31-Aug covers
 * the whole of 31-Aug without double counting the boundary into September.
 */
export const REPORT_TIME_ZONE = 'Asia/Kolkata';

export const DATE_PRESETS = [
  'today',
  'yesterday',
  'this_week',
  'this_month',
  'previous_month',
  'custom',
] as const;

export type DatePreset = (typeof DATE_PRESETS)[number];

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;

export type ResolvedRange = {
  preset: DatePreset;
  /** Inclusive local calendar day. */
  from_date: string;
  /** Inclusive local calendar day. */
  to_date: string;
  /** Half-open UTC instants for the SQL predicate. */
  from_instant: string;
  to_instant: string;
  time_zone: string;
};

/** Offset of a zone from UTC at a given instant, in minutes. */
function zoneOffsetMinutes(at: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(at);
  const lookup = (type: string) =>
    Number.parseInt(parts.find((part) => part.type === type)?.value ?? '0', 10);
  const asUtc = Date.UTC(
    lookup('year'),
    lookup('month') - 1,
    lookup('day'),
    lookup('hour') === 24 ? 0 : lookup('hour'),
    lookup('minute'),
    lookup('second'),
  );
  return (asUtc - Math.floor(at.getTime() / 1000) * 1000) / 60_000;
}

/** The UTC instant of local midnight starting `dateOnly` in `timeZone`. */
function localMidnightToUtc(dateOnly: string, timeZone: string): Date {
  const [year, month, day] = dateOnly.split('-').map((part) => Number(part));
  const guess = Date.UTC(year, month - 1, day, 0, 0, 0);
  // Two passes settle any DST transition; India has none, but this keeps the
  // helper correct if another zone is ever configured.
  let instant = new Date(guess);
  for (let pass = 0; pass < 2; pass += 1) {
    const offset = zoneOffsetMinutes(instant, timeZone);
    instant = new Date(guess - offset * 60_000);
  }
  return instant;
}

/** Local calendar day of an instant, as YYYY-MM-DD. */
export function localDateOf(at: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(at);
  return parts;
}

function addDays(dateOnly: string, days: number): string {
  const [year, month, day] = dateOnly.split('-').map((part) => Number(part));
  const shifted = new Date(Date.UTC(year, month - 1, day + days));
  return shifted.toISOString().slice(0, 10);
}

function startOfMonth(dateOnly: string): string {
  return `${dateOnly.slice(0, 7)}-01`;
}

function endOfMonth(dateOnly: string): string {
  const [year, month] = dateOnly.split('-').map((part) => Number(part));
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return `${dateOnly.slice(0, 7)}-${String(lastDay).padStart(2, '0')}`;
}

/** Monday-start week, matching the Indian business convention used elsewhere. */
function startOfWeek(dateOnly: string): string {
  const [year, month, day] = dateOnly.split('-').map((part) => Number(part));
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  const backTo = weekday === 0 ? 6 : weekday - 1;
  return addDays(dateOnly, -backTo);
}

export function resolveRange(
  input: { preset?: string; from?: string; to?: string },
  now: Date = new Date(),
  timeZone: string = REPORT_TIME_ZONE,
): ResolvedRange {
  const preset = (input.preset ?? (input.from || input.to ? 'custom' : 'today')) as DatePreset;
  if (!DATE_PRESETS.includes(preset)) {
    throw new ApiError(
      ErrorCodes.REPORT_RANGE_INVALID,
      `preset must be one of ${DATE_PRESETS.join(', ')}`,
      422,
    );
  }

  const today = localDateOf(now, timeZone);
  let fromDate: string;
  let toDate: string;

  if (preset === 'today') {
    fromDate = today;
    toDate = today;
  } else if (preset === 'yesterday') {
    fromDate = addDays(today, -1);
    toDate = fromDate;
  } else if (preset === 'this_week') {
    fromDate = startOfWeek(today);
    toDate = today;
  } else if (preset === 'this_month') {
    fromDate = startOfMonth(today);
    toDate = today;
  } else if (preset === 'previous_month') {
    const previous = addDays(startOfMonth(today), -1);
    fromDate = startOfMonth(previous);
    toDate = endOfMonth(previous);
  } else {
    if (!input.from || !input.to) {
      throw new ApiError(
        ErrorCodes.REPORT_RANGE_INVALID,
        'A custom range requires both from and to dates',
        422,
      );
    }
    if (!DATE_ONLY.test(input.from) || !DATE_ONLY.test(input.to)) {
      throw new ApiError(
        ErrorCodes.REPORT_RANGE_INVALID,
        'from and to must be YYYY-MM-DD dates',
        422,
      );
    }
    fromDate = input.from;
    toDate = input.to;
  }

  if (fromDate > toDate) {
    throw new ApiError(
      ErrorCodes.REPORT_RANGE_INVALID,
      'from date cannot be after to date',
      422,
    );
  }

  return {
    preset,
    from_date: fromDate,
    to_date: toDate,
    // to_date is inclusive, so the half-open upper bound is the next midnight.
    from_instant: localMidnightToUtc(fromDate, timeZone).toISOString(),
    to_instant: localMidnightToUtc(addDays(toDate, 1), timeZone).toISOString(),
    time_zone: timeZone,
  };
}
