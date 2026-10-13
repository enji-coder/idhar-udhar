import {
  effectiveRiderOnlineStatus,
  isRiderPresenceFresh,
} from './rider-presence';

describe('rider presence policy', () => {
  const staleMs = 180_000;
  const now = Date.parse('2026-10-13T12:00:00.000Z');

  it('treats a fresh last_seen as present', () => {
    expect(
      isRiderPresenceFresh(new Date(now - 30_000), now, staleMs),
    ).toBe(true);
    expect(
      effectiveRiderOnlineStatus('ONLINE', new Date(now - 30_000), now, staleMs),
    ).toBe('ONLINE');
  });

  it('expires presence after the configurable stale window', () => {
    expect(
      isRiderPresenceFresh(new Date(now - staleMs - 1), now, staleMs),
    ).toBe(false);
    expect(
      effectiveRiderOnlineStatus(
        'ONLINE',
        new Date(now - staleMs - 1),
        now,
        staleMs,
      ),
    ).toBe('OFFLINE');
  });

  it('treats missing last_seen as not present without inventing Online', () => {
    expect(isRiderPresenceFresh(null, now, staleMs)).toBe(false);
    expect(effectiveRiderOnlineStatus('ONLINE', null, now, staleMs)).toBe(
      'OFFLINE',
    );
  });

  it('keeps explicit Offline offline even with a fresh last_seen', () => {
    expect(
      effectiveRiderOnlineStatus('OFFLINE', new Date(now), now, staleMs),
    ).toBe('OFFLINE');
  });
});
