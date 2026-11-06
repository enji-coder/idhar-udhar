import {
  classifyEarningSettlement,
  earningSettlementState,
  inrPaise,
} from './earning-settlement';

describe('earning settlement classification', () => {
  it('splits a ₹124.00 cash fare into ₹105.40 and ₹18.60 without a wallet credit', () => {
    const fare = inrPaise('124.00');
    const rider = (fare * 85) / 100;
    const company = fare - rider;
    expect(rider).toBe(10540);
    expect(company).toBe(1860);
    expect(rider + company).toBe(fare);

    const status = classifyEarningSettlement({
      cashCollected: '124.00',
      walletCredited: '0.00',
      codApplied: '0.00',
    });
    expect(status).toBe('CASH');
    expect(
      earningSettlementState({
        status,
        riderAmount: '105.40',
        cashCollected: '124.00',
        walletCredited: '0.00',
        codApplied: '0.00',
        companySharePosted: '18.60',
      }),
    ).toBe('SETTLED');
  });

  it('keeps a cash trip pending until the company share is debited from the wallet', () => {
    const status = classifyEarningSettlement({
      cashCollected: '124.00',
      walletCredited: '0.00',
      codApplied: '0.00',
    });
    expect(
      earningSettlementState({
        status,
        riderAmount: '105.40',
        cashCollected: '124.00',
        walletCredited: '0.00',
        codApplied: '0.00',
        companySharePosted: '0.00',
        companyShareWalletDebit: '0.00',
      }),
    ).toBe('PENDING');
    expect(
      earningSettlementState({
        status,
        riderAmount: '105.40',
        cashCollected: '124.00',
        walletCredited: '0.00',
        codApplied: '0.00',
        companySharePosted: '0.00',
        companyShareWalletDebit: '18.60',
      }),
    ).toBe('SETTLED');
  });

  it('reports a verified online earning as credited once', () => {
    const status = classifyEarningSettlement({
      cashCollected: '0.00',
      walletCredited: '105.40',
      codApplied: '0.00',
    });
    expect(status).toBe('CREDITED');
    expect(
      earningSettlementState({
        status,
        riderAmount: '105.40',
        cashCollected: '0.00',
        walletCredited: '105.40',
        codApplied: '0.00',
        companySharePosted: '0.00',
      }),
    ).toBe('SETTLED');
  });

  it('reports an online earning that only reduced COD Due', () => {
    const status = classifyEarningSettlement({
      cashCollected: '0.00',
      walletCredited: '0.00',
      codApplied: '105.40',
    });
    expect(status).toBe('APPLIED_TO_COD');
    expect(
      earningSettlementState({
        status,
        riderAmount: '105.40',
        cashCollected: '0.00',
        walletCredited: '0.00',
        codApplied: '105.40',
        companySharePosted: '0.00',
      }),
    ).toBe('SETTLED');
  });

  it('reports a split between the wallet and COD Due', () => {
    const status = classifyEarningSettlement({
      cashCollected: '0.00',
      walletCredited: '50.00',
      codApplied: '55.40',
    });
    expect(status).toBe('CREDITED_AND_COD');
    expect(
      earningSettlementState({
        status,
        riderAmount: '105.40',
        cashCollected: '0.00',
        walletCredited: '50.00',
        codApplied: '55.40',
        companySharePosted: '0.00',
      }),
    ).toBe('SETTLED');
  });

  it('leaves an unpaid online trip pending and does not treat a partial credit as settled', () => {
    expect(
      classifyEarningSettlement({
        cashCollected: '0.00',
        walletCredited: '0.00',
        codApplied: '0.00',
      }),
    ).toBe('PENDING');
    const partial = classifyEarningSettlement({
      cashCollected: '0.00',
      walletCredited: '40.00',
      codApplied: '0.00',
    });
    expect(partial).toBe('CREDITED');
    expect(
      earningSettlementState({
        status: partial,
        riderAmount: '105.40',
        cashCollected: '0.00',
        walletCredited: '40.00',
        codApplied: '0.00',
        companySharePosted: '0.00',
      }),
    ).toBe('PENDING');
  });
});
