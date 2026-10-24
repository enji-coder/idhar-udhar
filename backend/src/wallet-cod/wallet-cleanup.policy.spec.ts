import {
  assessCodCleanup,
  assessCustomerWalletCleanup,
  assessRiderWalletCleanup,
} from './wallet-cleanup.policy';

describe('wallet cleanup policy', () => {
  it('reverses an untied admin adjustment and reduces the ledger balance', () => {
    const decision = assessRiderWalletCleanup({
      entryType: 'ADJUSTMENT',
      direction: 'CREDIT',
      amount: '25.50',
      balance: '40.00',
      relatedOrderId: null,
      relatedPaymentTransactionId: null,
      relatedCodLedgerId: null,
      pairedCodSource: null,
      alreadyReversed: false,
    });
    expect(decision.allowed).toBe(true);
    expect(decision.projected_balance).toBe('14.50');
  });

  it('refuses a payment-linked recharge', () => {
    const decision = assessRiderWalletCleanup({
      entryType: 'RECHARGE',
      direction: 'CREDIT',
      amount: '100.00',
      balance: '100.00',
      relatedOrderId: null,
      relatedPaymentTransactionId: 'pay-1',
      relatedCodLedgerId: null,
      pairedCodSource: null,
      alreadyReversed: false,
    });
    expect(decision.allowed).toBe(false);
    expect(decision.reasons.join(' ')).toMatch(/payment transaction/i);
  });

  it('refuses an order earning and a payout', () => {
    expect(assessRiderWalletCleanup({
      entryType: 'EARNING',
      direction: 'CREDIT',
      amount: '10.00',
      balance: '10.00',
      relatedOrderId: 'order-1',
      relatedPaymentTransactionId: null,
      relatedCodLedgerId: null,
      pairedCodSource: null,
      alreadyReversed: false,
    }).allowed).toBe(false);
    expect(assessRiderWalletCleanup({
      entryType: 'PAYOUT',
      direction: 'DEBIT',
      amount: '10.00',
      balance: '0.00',
      relatedOrderId: null,
      relatedPaymentTransactionId: null,
      relatedCodLedgerId: null,
      pairedCodSource: null,
      alreadyReversed: false,
    }).allowed).toBe(false);
  });

  it('refuses a reversal that would make the wallet negative', () => {
    const decision = assessRiderWalletCleanup({
      entryType: 'ADJUSTMENT',
      direction: 'CREDIT',
      amount: '30.00',
      balance: '10.00',
      relatedOrderId: null,
      relatedPaymentTransactionId: null,
      relatedCodLedgerId: null,
      pairedCodSource: null,
      alreadyReversed: false,
    });
    expect(decision.allowed).toBe(false);
    expect(decision.reasons.join(' ')).toMatch(/negative/i);
  });

  it('keeps settled COD and allows an untied admin adjustment', () => {
    expect(assessCodCleanup({
      source: 'CASH_COMPANY_SHARE',
      direction: 'INCREASE',
      amount: '15.00',
      codDue: '15.00',
      relatedOrderId: 'order-1',
      relatedWalletEntryType: null,
      alreadyReversed: false,
    }).allowed).toBe(false);
    const adjustment = assessCodCleanup({
      source: 'ADMIN_ADJUSTMENT',
      direction: 'INCREASE',
      amount: '5.00',
      codDue: '5.00',
      relatedOrderId: null,
      relatedWalletEntryType: null,
      alreadyReversed: false,
    });
    expect(adjustment.allowed).toBe(true);
    expect(adjustment.projected_balance).toBe('0.00');
  });

  it('keeps customer refunds and allows an untied adjustment', () => {
    expect(assessCustomerWalletCleanup({
      entryType: 'REFUND',
      direction: 'CREDIT',
      amount: '8.00',
      balance: '8.00',
      relatedOrderId: null,
      alreadyReversed: false,
    }).allowed).toBe(false);
    expect(assessCustomerWalletCleanup({
      entryType: 'ADJUSTMENT',
      direction: 'CREDIT',
      amount: '8.00',
      balance: '8.00',
      relatedOrderId: null,
      alreadyReversed: false,
    }).projected_balance).toBe('0.00');
  });

  it('refuses a paired COD reversal that would make COD due negative', () => {
    const decision = assessRiderWalletCleanup({
      entryType: 'ADJUSTMENT',
      direction: 'CREDIT',
      amount: '5.00',
      balance: '20.00',
      relatedOrderId: null,
      relatedPaymentTransactionId: null,
      relatedCodLedgerId: 'cod-1',
      pairedCodSource: 'ADMIN_ADJUSTMENT',
      pairedCod: { direction: 'INCREASE', amount: '12.00', due: '4.00' },
      alreadyReversed: false,
    });
    expect(decision.allowed).toBe(false);
    expect(decision.reasons.join(' ')).toMatch(/COD due negative/i);
  });

  it('refuses a paired wallet reversal that would make the wallet negative', () => {
    const decision = assessCodCleanup({
      source: 'ADMIN_ADJUSTMENT',
      direction: 'DECREASE',
      amount: '2.00',
      codDue: '10.00',
      relatedOrderId: null,
      relatedWalletEntryType: 'ADJUSTMENT',
      pairedWallet: { direction: 'CREDIT', amount: '9.00', balance: '3.00' },
      alreadyReversed: false,
    });
    expect(decision.allowed).toBe(false);
    expect(decision.reasons.join(' ')).toMatch(/wallet balance negative/i);
  });

  it('does not treat a zero-looking description as enough to delete', () => {
    const decision = assessRiderWalletCleanup({
      entryType: 'EARNING',
      direction: 'CREDIT',
      amount: '0.01',
      balance: '0.01',
      relatedOrderId: 'order-1',
      relatedPaymentTransactionId: null,
      relatedCodLedgerId: null,
      pairedCodSource: null,
      alreadyReversed: false,
    });
    expect(decision.allowed).toBe(false);
  });
});
