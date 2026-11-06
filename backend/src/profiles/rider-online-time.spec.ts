import {
  localDayWindow,
  onlineDayReport,
  onlineSessionAction,
  StoredOnlineSession,
  todayLocalDate,
} from './rider-online-time';

const rider = '11111111-1111-4111-8111-111111111111';

function session(
  id: string,
  startedAt: string,
  endedAt: string | null,
): StoredOnlineSession {
  return {
    sessionId: id,
    riderProfileId: rider,
    startedAt: new Date(startedAt),
    endedAt: endedAt ? new Date(endedAt) : null,
  };
}

describe('online session actions', () => {
  it('opens one session when the rider goes online', () => {
    expect(
      onlineSessionAction({
        currentlyOnline: false,
        goingOnline: true,
        hasOpenSession: false,
        presenceFresh: false,
      }),
    ).toBe('open');
  });

  it('keeps the same session when Online is repeated while presence is fresh', () => {
    expect(
      onlineSessionAction({
        currentlyOnline: true,
        goingOnline: true,
        hasOpenSession: true,
        presenceFresh: true,
      }),
    ).toBe('keep');
  });

  it('does nothing when Offline is repeated and no session is open', () => {
    expect(
      onlineSessionAction({
        currentlyOnline: false,
        goingOnline: false,
        hasOpenSession: false,
        presenceFresh: false,
      }),
    ).toBe('keep');
  });

  it('closes the open session on Offline', () => {
    expect(
      onlineSessionAction({
        currentlyOnline: true,
        goingOnline: false,
        hasOpenSession: true,
        presenceFresh: true,
      }),
    ).toBe('close');
  });

  it('closes a stale session before opening the next shift', () => {
    expect(
      onlineSessionAction({
        currentlyOnline: true,
        goingOnline: true,
        hasOpenSession: true,
        presenceFresh: false,
      }),
    ).toBe('close_then_open');
  });

  it('opens a session if the rider is online but the row was never started', () => {
    expect(
      onlineSessionAction({
        currentlyOnline: true,
        goingOnline: true,
        hasOpenSession: false,
        presenceFresh: true,
      }),
    ).toBe('open');
  });
});

describe('local day window', () => {
  it('splits the Asia/Kolkata calendar at 18:30 UTC', () => {
    const window = localDayWindow(
      '2026-11-06',
      new Date('2026-11-06T12:00:00.000Z'),
    );
    expect(window.timeZone).toBe('Asia/Kolkata');
    expect(window.date).toBe('2026-11-06');
    expect(window.from.toISOString()).toBe('2026-11-05T18:30:00.000Z');
    expect(window.to.toISOString()).toBe('2026-11-06T18:30:00.000Z');
  });

  it('moves today forward at local midnight', () => {
    expect(todayLocalDate(new Date('2026-11-06T18:29:59.000Z'))).toBe(
      '2026-11-06',
    );
    expect(todayLocalDate(new Date('2026-11-06T18:30:00.000Z'))).toBe(
      '2026-11-07',
    );
  });

  it('rejects a date that is not YYYY-MM-DD', () => {
    expect(() => localDayWindow('06-11-2026')).toThrow(
      expect.objectContaining({ code: 'REPORT_RANGE_INVALID' }),
    );
  });
});

describe('daily online duration', () => {
  const dayStart = new Date('2026-11-05T18:30:00.000Z');
  const dayEnd = new Date('2026-11-06T18:30:00.000Z');
  const nextEnd = new Date('2026-11-07T18:30:00.000Z');

  it('sums several shifts on the same local day', () => {
    const report = onlineDayReport(
      [
        session('a', '2026-11-06T03:00:00.000Z', '2026-11-06T04:00:00.000Z'),
        session('b', '2026-11-06T08:00:00.000Z', '2026-11-06T08:30:00.000Z'),
      ],
      dayStart,
      dayEnd,
      new Date('2026-11-06T12:00:00.000Z'),
    );
    expect(report.shifts.map((shift) => shift.seconds)).toEqual([3600, 1800]);
    expect(report.totalSeconds).toBe(5400);
    expect(report.active).toBeNull();
  });

  it('splits a shift at local midnight without double counting', () => {
    const crossing = session(
      'night',
      '2026-11-06T17:30:00.000Z',
      '2026-11-06T19:30:00.000Z',
    );
    const first = onlineDayReport(
      [crossing],
      dayStart,
      dayEnd,
      new Date('2026-11-07T02:00:00.000Z'),
    );
    const second = onlineDayReport(
      [crossing],
      dayEnd,
      nextEnd,
      new Date('2026-11-07T02:00:00.000Z'),
    );
    expect(first.totalSeconds).toBe(3600);
    expect(second.totalSeconds).toBe(3600);
    expect(first.totalSeconds + second.totalSeconds).toBe(7200);
  });

  it('does not count an overlapping duplicate span twice', () => {
    const report = onlineDayReport(
      [
        session('a', '2026-11-06T04:00:00.000Z', '2026-11-06T05:00:00.000Z'),
        session('b', '2026-11-06T04:30:00.000Z', '2026-11-06T05:30:00.000Z'),
      ],
      dayStart,
      dayEnd,
      new Date('2026-11-06T12:00:00.000Z'),
    );
    expect(report.shifts).toHaveLength(2);
    expect(report.totalSeconds).toBe(5400);
  });

  it('reports an open session up to the server clock and keeps it active', () => {
    const report = onlineDayReport(
      [session('live', '2026-11-06T10:00:00.000Z', null)],
      dayStart,
      dayEnd,
      new Date('2026-11-06T10:15:30.000Z'),
    );
    expect(report.active).toEqual({
      sessionId: 'live',
      startedAt: '2026-11-06T10:00:00.000Z',
      elapsedSeconds: 930,
    });
    expect(report.totalSeconds).toBe(930);
    expect(report.shifts[0]?.active).toBe(true);
    expect(report.shifts[0]?.endedAt).toBeNull();
  });

  it('does not mark yesterday portion of a still-open shift as the active slice', () => {
    const report = onlineDayReport(
      [session('live', '2026-11-06T17:00:00.000Z', null)],
      dayStart,
      dayEnd,
      new Date('2026-11-06T19:00:00.000Z'),
    );
    expect(report.totalSeconds).toBe(5400);
    expect(report.shifts[0]?.active).toBe(false);
    expect(report.active).toBeNull();
  });
});
