/**
 * Pickup waiting math. Matches order_waiting_charges:
 * elapsed minutes are FLOOR(seconds / 60) completed minutes,
 * chargeable minutes are GREATEST(0, elapsed - free),
 * amount is those minutes times the snapshotted per-minute rate.
 * At exactly the free threshold the charge is zero.
 * This does not apply the trip-fare 85/15 split.
 */

export type WaitingAssessment = {
  elapsedMinutes: number;
  chargeableMinutes: number;
  amount: string;
};

export function completedWaitingMinutes(elapsedSeconds: number): number {
  if (!Number.isFinite(elapsedSeconds) || elapsedSeconds <= 0) {
    return 0;
  }
  return Math.floor(elapsedSeconds / 60);
}

export function assessWaitingCharge(input: {
  elapsedSeconds: number;
  initialWaitingMinutes: number;
  perMinute: string;
}): WaitingAssessment {
  const elapsedMinutes = completedWaitingMinutes(input.elapsedSeconds);
  const free = Number.isFinite(input.initialWaitingMinutes)
    ? Math.max(0, Math.trunc(input.initialWaitingMinutes))
    : 0;
  const chargeableMinutes = Math.max(0, elapsedMinutes - free);
  const amount = formatPaise(chargeableMinutes * inrToPaise(input.perMinute));
  return { elapsedMinutes, chargeableMinutes, amount };
}

export function elapsedSecondsBetween(start: Date, end: Date): number | null {
  const ms = end.getTime() - start.getTime();
  if (!Number.isFinite(ms)) {
    return null;
  }
  if (ms <= 0) {
    return 0;
  }
  return Math.floor(ms / 1000);
}

function inrToPaise(raw: string): number {
  const trimmed = raw.trim();
  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(trimmed);
  if (!match) {
    throw new Error('Invalid waiting rate');
  }
  const whole = Number.parseInt(match[1], 10);
  const frac = (match[2] ?? '').padEnd(2, '0');
  return whole * 100 + Number.parseInt(frac, 10);
}

function formatPaise(paise: number): string {
  const safe = Number.isFinite(paise) && paise > 0 ? Math.trunc(paise) : 0;
  const whole = Math.floor(safe / 100);
  const frac = String(safe % 100).padStart(2, '0');
  return `${whole}.${frac}`;
}
