/**
 * Shared Online presence policy for Admin display and dispatch eligibility.
 *
 * A rider with online_status=ONLINE is treated as present only while
 * last_seen_at is fresh. Missing/invalid/stale last_seen means Offline /
 * not dispatchable — including after the app is killed (no heartbeats).
 *
 * Default window is configured via RIDER_PRESENCE_STALE_MS (see AppConfig).
 * Flutter keeps last_seen fresh while Online via a foreground service; Dart
 * timers alone freeze when the app is backgrounded on Android.
 */
export function isRiderPresenceFresh(
  lastSeenAt: Date | string | null | undefined,
  nowMs: number,
  staleMs: number,
): boolean {
  if (!lastSeenAt) {
    return false;
  }
  const seen =
    lastSeenAt instanceof Date ? lastSeenAt : new Date(lastSeenAt);
  if (Number.isNaN(seen.getTime())) {
    return false;
  }
  return nowMs - seen.getTime() <= staleMs;
}

export function effectiveRiderOnlineStatus(
  onlineStatus: string,
  lastSeenAt: Date | string | null | undefined,
  nowMs: number,
  staleMs: number,
): string {
  if (onlineStatus !== 'ONLINE') {
    return onlineStatus;
  }
  return isRiderPresenceFresh(lastSeenAt, nowMs, staleMs)
    ? 'ONLINE'
    : 'OFFLINE';
}
