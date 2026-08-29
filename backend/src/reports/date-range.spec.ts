import { localDateOf, REPORT_TIME_ZONE, resolveRange } from './date-range';

// 2026-08-15 is a Saturday. 06:30 UTC is 12:00 IST, safely mid-day in the
// report zone so presets do not straddle a boundary by accident.
const NOW = new Date('2026-08-15T06:30:00.000Z');

describe('resolveRange', () => {
  it('resolves today as a single inclusive local day', () => {
    const range = resolveRange({ preset: 'today' }, NOW);
    expect(range.from_date).toBe('2026-08-15');
    expect(range.to_date).toBe('2026-08-15');
    // Local midnight IST is 18:30 UTC the previous day.
    expect(range.from_instant).toBe('2026-08-14T18:30:00.000Z');
    expect(range.to_instant).toBe('2026-08-15T18:30:00.000Z');
    expect(range.time_zone).toBe(REPORT_TIME_ZONE);
  });

  it('resolves yesterday without overlapping today', () => {
    const yesterday = resolveRange({ preset: 'yesterday' }, NOW);
    const today = resolveRange({ preset: 'today' }, NOW);
    expect(yesterday.from_date).toBe('2026-08-14');
    expect(yesterday.to_date).toBe('2026-08-14');
    // Half-open ranges meet exactly, so no instant belongs to both.
    expect(yesterday.to_instant).toBe(today.from_instant);
  });

  it('resolves this week from Monday', () => {
    const range = resolveRange({ preset: 'this_week' }, NOW);
    expect(range.from_date).toBe('2026-08-10');
    expect(range.to_date).toBe('2026-08-15');
  });

  it('resolves this month from the first', () => {
    const range = resolveRange({ preset: 'this_month' }, NOW);
    expect(range.from_date).toBe('2026-08-01');
    expect(range.to_date).toBe('2026-08-15');
  });

  it('resolves the previous month in full', () => {
    const range = resolveRange({ preset: 'previous_month' }, NOW);
    expect(range.from_date).toBe('2026-07-01');
    expect(range.to_date).toBe('2026-07-31');
    expect(range.from_instant).toBe('2026-06-30T18:30:00.000Z');
    expect(range.to_instant).toBe('2026-07-31T18:30:00.000Z');
  });

  it('handles a previous month with 28 days', () => {
    const range = resolveRange(
      { preset: 'previous_month' },
      new Date('2026-03-10T06:30:00.000Z'),
    );
    expect(range.from_date).toBe('2026-02-01');
    expect(range.to_date).toBe('2026-02-28');
  });

  it('treats a custom to date as inclusive', () => {
    const range = resolveRange(
      { preset: 'custom', from: '2026-08-01', to: '2026-08-31' },
      NOW,
    );
    expect(range.from_instant).toBe('2026-07-31T18:30:00.000Z');
    // The whole of 31-Aug is inside the range.
    expect(range.to_instant).toBe('2026-08-31T18:30:00.000Z');
  });

  it('covers a single-day custom range', () => {
    const range = resolveRange(
      { preset: 'custom', from: '2026-08-05', to: '2026-08-05' },
      NOW,
    );
    expect(range.from_instant).toBe('2026-08-04T18:30:00.000Z');
    expect(range.to_instant).toBe('2026-08-05T18:30:00.000Z');
  });

  it('infers a custom preset when dates are supplied', () => {
    const range = resolveRange({ from: '2026-08-01', to: '2026-08-02' }, NOW);
    expect(range.preset).toBe('custom');
  });

  it('rejects an inverted, incomplete or malformed range', () => {
    expect(() =>
      resolveRange({ preset: 'custom', from: '2026-08-31', to: '2026-08-01' }, NOW),
    ).toThrow(/cannot be after/);
    expect(() => resolveRange({ preset: 'custom', from: '2026-08-01' }, NOW)).toThrow(
      /requires both/,
    );
    expect(() =>
      resolveRange({ preset: 'custom', from: '01-08-2026', to: '2026-08-02' }, NOW),
    ).toThrow(/YYYY-MM-DD/);
    expect(() => resolveRange({ preset: 'last_decade' }, NOW)).toThrow(
      /preset must be one of/,
    );
  });
});

describe('localDateOf', () => {
  it('maps an instant to the report zone calendar day', () => {
    // 18:45 UTC is already the next day in IST.
    expect(localDateOf(new Date('2026-08-14T18:45:00.000Z'), REPORT_TIME_ZONE)).toBe(
      '2026-08-15',
    );
    expect(localDateOf(new Date('2026-08-14T18:15:00.000Z'), REPORT_TIME_ZONE)).toBe(
      '2026-08-14',
    );
  });
});
