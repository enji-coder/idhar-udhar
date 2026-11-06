import { isRiderPresenceFresh } from './rider-presence';
import { resolveRange, REPORT_TIME_ZONE } from '../reports/date-range';

export { isRiderPresenceFresh };

export const ONLINE_TIME_ZONE = REPORT_TIME_ZONE;

export type OnlineSessionAction = 'keep' | 'open' | 'close' | 'close_then_open';

/**
 * One open session per rider. A repeated Online while presence is still fresh
 * keeps that session. A repeated Offline with nothing open is a no-op.
 * A stale or stray open session is closed before a new one starts.
 */
export function onlineSessionAction(input: {
  currentlyOnline: boolean;
  goingOnline: boolean;
  hasOpenSession: boolean;
  presenceFresh: boolean;
}): OnlineSessionAction {
  if (!input.goingOnline) {
    return input.hasOpenSession ? 'close' : 'keep';
  }
  if (input.currentlyOnline && input.presenceFresh) {
    return input.hasOpenSession ? 'keep' : 'open';
  }
  return input.hasOpenSession ? 'close_then_open' : 'open';
}

export type StoredOnlineSession = {
  sessionId: string;
  riderProfileId: string;
  startedAt: Date;
  endedAt: Date | null;
};

export type OnlineShiftSlice = {
  sessionId: string;
  startedAt: string;
  endedAt: string | null;
  seconds: number;
  active: boolean;
};

export type OnlineDayReport = {
  totalSeconds: number;
  shifts: OnlineShiftSlice[];
  active: {
    sessionId: string;
    startedAt: string;
    elapsedSeconds: number;
  } | null;
};

type Span = { startMs: number; endMs: number };

/** Half-open [from, to) for one Asia/Kolkata calendar day. */
export function localDayWindow(date: string, now: Date = new Date()): {
  date: string;
  timeZone: string;
  from: Date;
  to: Date;
} {
  const range = resolveRange(
    { preset: 'custom', from: date, to: date },
    now,
    ONLINE_TIME_ZONE,
  );
  return {
    date: range.from_date,
    timeZone: range.time_zone,
    from: new Date(range.from_instant),
    to: new Date(range.to_instant),
  };
}

export function todayLocalDate(now: Date = new Date()): string {
  return resolveRange({ preset: 'today' }, now, ONLINE_TIME_ZONE).from_date;
}

function mergeSpans(spans: Span[]): Span[] {
  const sorted = spans
    .filter((span) => span.endMs > span.startMs)
    .sort((a, b) => a.startMs - b.startMs || a.endMs - b.endMs);
  const merged: Span[] = [];
  for (const span of sorted) {
    const last = merged[merged.length - 1];
    if (!last || span.startMs > last.endMs) {
      merged.push({ startMs: span.startMs, endMs: span.endMs });
    } else if (span.endMs > last.endMs) {
      last.endMs = span.endMs;
    }
  }
  return merged;
}

/**
 * Portion of each session that falls on [windowStart, windowEnd).
 * Overlapping spans are merged before the daily total so the same minute
 * is not counted twice. An open session is measured up to `asOf`.
 */
export function onlineDayReport(
  sessions: StoredOnlineSession[],
  windowStart: Date,
  windowEnd: Date,
  asOf: Date,
): OnlineDayReport {
  const windowFrom = windowStart.getTime();
  const windowTo = windowEnd.getTime();
  const nowMs = asOf.getTime();
  const viewingToday = nowMs >= windowFrom && nowMs < windowTo;
  const spans: Span[] = [];
  const shifts: OnlineShiftSlice[] = [];
  let active: OnlineDayReport['active'] = null;

  const ordered = [...sessions].sort(
    (a, b) => a.startedAt.getTime() - b.startedAt.getTime(),
  );
  for (const session of ordered) {
    const startMs = session.startedAt.getTime();
    if (Number.isNaN(startMs)) {
      continue;
    }
    const open = session.endedAt == null;
    const rawEnd = open ? nowMs : session.endedAt!.getTime();
    const endMs = Math.max(startMs, rawEnd);
    const overlapStart = Math.max(startMs, windowFrom);
    const overlapEnd = Math.min(endMs, windowTo);
    if (overlapEnd <= overlapStart) {
      continue;
    }
    spans.push({ startMs: overlapStart, endMs: overlapEnd });
    const sliceActive = open && viewingToday && overlapEnd >= nowMs;
    shifts.push({
      sessionId: session.sessionId,
      startedAt: new Date(overlapStart).toISOString(),
      endedAt: sliceActive ? null : new Date(overlapEnd).toISOString(),
      seconds: Math.floor((overlapEnd - overlapStart) / 1000),
      active: sliceActive,
    });
    if (open && viewingToday) {
      active = {
        sessionId: session.sessionId,
        startedAt: session.startedAt.toISOString(),
        elapsedSeconds: Math.floor(Math.max(0, nowMs - startMs) / 1000),
      };
    }
  }

  const totalMs = mergeSpans(spans).reduce(
    (sum, span) => sum + (span.endMs - span.startMs),
    0,
  );
  return {
    totalSeconds: Math.floor(totalMs / 1000),
    shifts,
    active,
  };
}
