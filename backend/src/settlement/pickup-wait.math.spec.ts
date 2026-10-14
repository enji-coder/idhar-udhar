import {
  assessWaitingCharge,
  completedWaitingMinutes,
  elapsedSecondsBetween,
} from './pickup-wait.math';

describe('pickup waiting charge', () => {
  it('floors elapsed time to completed minutes', () => {
    expect(completedWaitingMinutes(0)).toBe(0);
    expect(completedWaitingMinutes(59)).toBe(0);
    expect(completedWaitingMinutes(60)).toBe(1);
    expect(completedWaitingMinutes(659)).toBe(10);
  });

  it('does not charge bike or scooter time inside a 10 minute free period', () => {
    const atThreshold = assessWaitingCharge({
      elapsedSeconds: 10 * 60,
      initialWaitingMinutes: 10,
      perMinute: '2.50',
    });
    expect(atThreshold).toEqual({
      elapsedMinutes: 10,
      chargeableMinutes: 0,
      amount: '0.00',
    });

    const justBeforeNextMinute = assessWaitingCharge({
      elapsedSeconds: 10 * 60 + 59,
      initialWaitingMinutes: 10,
      perMinute: '2.50',
    });
    expect(justBeforeNextMinute.chargeableMinutes).toBe(0);
    expect(justBeforeNextMinute.amount).toBe('0.00');
  });

  it('charges one completed minute after the free period using the snapshot rate', () => {
    const billed = assessWaitingCharge({
      elapsedSeconds: 11 * 60,
      initialWaitingMinutes: 10,
      perMinute: '2.50',
    });
    expect(billed).toEqual({
      elapsedMinutes: 11,
      chargeableMinutes: 1,
      amount: '2.50',
    });
  });

  it('bills only completed intervals and ignores a client-sized amount', () => {
    const billed = assessWaitingCharge({
      elapsedSeconds: 12 * 60 + 30,
      initialWaitingMinutes: 10,
      perMinute: '1.25',
    });
    expect(billed.elapsedMinutes).toBe(12);
    expect(billed.chargeableMinutes).toBe(2);
    expect(billed.amount).toBe('2.50');
  });

  it('returns zero when the arrival timestamp is not after the end', () => {
    const start = new Date('2026-10-14T08:00:00.000Z');
    expect(elapsedSecondsBetween(start, start)).toBe(0);
    expect(
      elapsedSecondsBetween(start, new Date('2026-10-14T07:59:00.000Z')),
    ).toBe(0);
    expect(
      elapsedSecondsBetween(start, new Date('2026-10-14T08:01:05.000Z')),
    ).toBe(65);
  });
});
