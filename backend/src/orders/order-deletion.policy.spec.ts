import { decideOrderHide, decideOrderPurge, OrderDependencyCounts } from './order-deletion.policy';

const empty = (): OrderDependencyCounts => ({
  payments: 0,
  wallet: 0,
  cod: 0,
  customer_wallet: 0,
  receivables: 0,
  invoices: 0,
  finance: 0,
  cancellations: 0,
  adjustments: 0,
  resends: 0,
  tax: 0,
  children: 0,
  waiting: 0,
});

describe('order deletion policy', () => {
  it('allows a cancelled historical order with no financial records', () => {
    expect(decideOrderPurge('CANCELLED', empty()).allowed).toBe(true);
  });

  it('allows a delivered order when nothing financial was posted', () => {
    expect(decideOrderPurge('DELIVERED', empty()).allowed).toBe(true);
  });

  it('blocks an active trip even when it has no ledger rows', () => {
    const decision = decideOrderPurge('IN_TRANSIT', empty());
    expect(decision.allowed).toBe(false);
    expect(decision.code).toBe('ORDER_DELETE_BLOCKED');
  });

  it('blocks purge when settled money exists and names the records', () => {
    const decision = decideOrderPurge('DELIVERED', { ...empty(), finance: 1, payments: 2 });
    expect(decision.allowed).toBe(false);
    expect(decision.code).toBe('ORDER_FINANCIAL_DEPENDENCY');
    expect(decision.blockers).toEqual(expect.arrayContaining(['payment transactions', 'finance snapshots']));
  });

  it('does not treat cancellation itself as a financial blocker', () => {
    expect(decideOrderPurge('CANCELLED', empty()).blockers).toEqual([]);
  });

  it('blocks every pickup waiting assessment, including a voided or zero-amount row', () => {
    const decision = decideOrderPurge('CANCELLED', { ...empty(), waiting: 1 });
    expect(decision.allowed).toBe(false);
    expect(decision.code).toBe('ORDER_FINANCIAL_DEPENDENCY');
    expect(decision.blockers).toEqual(['pickup waiting charges']);
  });

  it('hides a finished order and refuses an active one', () => {
    expect(decideOrderHide('CANCELLED').allowed).toBe(true);
    expect(decideOrderHide('ASSIGNED').allowed).toBe(false);
  });
});
