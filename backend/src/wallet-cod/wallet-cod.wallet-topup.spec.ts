import { WalletCodService } from './wallet-cod.service';

const RIDER_ID = '22222222-2222-4222-8222-222222222222';
const PAYMENT_TX_ID = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const SOURCE_TXN_ID = `wallet-topup:${PAYMENT_TX_ID}`;

describe('WalletCodService.applyVerifiedWalletTopUp', () => {
  function makeService(opts: {
    codDue: string;
    walletBalance?: string;
    existingWalletLedger?: boolean;
    existingCodLedger?: boolean;
    failOn?: 'insertCodLedger' | 'insertWalletLedger' | 'creditWallet';
  }) {
    let walletBalance = opts.walletBalance ?? '0.00';
    let codDue = opts.codDue;
    let walletLedgerByPayment = opts.existingWalletLedger
      ? { wallet_ledger_id: 'wallet-ledger-existing' }
      : null;
    let codSourceSeen = opts.existingCodLedger ?? false;
    const decreaseCalls: string[] = [];
    const creditCalls: string[] = [];
    const codLedgerInserts: Array<{ sourceTxnId?: string | null; amount: string }> =
      [];
    const walletLedgerInserts: Array<{
      relatedPaymentTransactionId?: string | null;
      amount: string;
    }> = [];

    const repo = {
      findWalletLedgerByPaymentTransactionId: jest.fn(async () => walletLedgerByPayment),
      lockAccounts: jest.fn(async () => ({
        wallet: {
          wallet_account_id: 'wallet-1',
          available_balance: walletBalance,
        },
        cod: { cod_account_id: 'cod-1', cod_due: codDue },
        threshold: '500.00',
      })),
      hasDigitalEarningSettlement: jest.fn(async (_codId: string, sourceTxnId: string) => {
        return codSourceSeen && sourceTxnId === SOURCE_TXN_ID;
      }),
      splitInflow: jest.fn(async (amount: string, due: string) => {
        const amountNum = Number(amount);
        const dueNum = Number(due);
        const settle = Math.min(amountNum, dueNum);
        const remainder = amountNum - settle;
        return {
          settle: settle.toFixed(2),
          remainder: remainder.toFixed(2),
        };
      }),
      isPositive: jest.fn(async (amount: string) => Number(amount) > 0),
      newIds: jest.fn(async () => ({
        walletLedgerId: 'wallet-ledger-new',
        codLedgerId: 'cod-ledger-new',
      })),
      decreaseCod: jest.fn(async (_id: string, amount: string) => {
        decreaseCalls.push(amount);
        codDue = (Number(codDue) - Number(amount)).toFixed(2);
        return codDue;
      }),
      creditWallet: jest.fn(async (_id: string, amount: string) => {
        if (opts.failOn === 'creditWallet') {
          throw new Error('credit failed');
        }
        creditCalls.push(amount);
        walletBalance = (Number(walletBalance) + Number(amount)).toFixed(2);
        return walletBalance;
      }),
      insertCodLedger: jest.fn(async (input: {
        amount: string;
        sourceTxnId?: string | null;
      }) => {
        if (opts.failOn === 'insertCodLedger') {
          throw new Error('cod ledger insert failed');
        }
        codLedgerInserts.push(input);
        codSourceSeen = true;
        return { cod_ledger_id: 'cod-ledger-1' };
      }),
      insertWalletLedger: jest.fn(async (input: {
        amount: string;
        relatedPaymentTransactionId?: string | null;
        walletLedgerId?: string;
      }) => {
        if (opts.failOn === 'insertWalletLedger') {
          throw new Error('wallet ledger insert failed');
        }
        walletLedgerInserts.push(input);
        walletLedgerByPayment = {
          wallet_ledger_id: input.walletLedgerId ?? 'wallet-ledger-1',
        };
        return { wallet_ledger_id: walletLedgerByPayment.wallet_ledger_id };
      }),
      operationalStatus: jest.fn(async () => 'CLEAR'),
      syncOperationalStatus: jest.fn(async () => 'CLEAR'),
      walletLedgerNet: jest.fn(async () => walletBalance),
      codLedgerNet: jest.fn(async () => codDue),
    };

    const walletNotifications = {
      onRechargeCompleted: jest.fn(async () => undefined),
      onCodSettlementCompleted: jest.fn(async () => undefined),
      onOperationalStatusChange: jest.fn(async () => undefined),
    };

    const service = new WalletCodService(
      {} as never,
      repo as never,
      {} as never,
      {} as never,
      walletNotifications as never,
      {} as never,
      { getOrThrow: () => ({}) } as never,
      {} as never,
      { info: jest.fn(), warn: jest.fn() } as never,
    );

    return {
      service,
      repo,
      walletNotifications,
      decreaseCalls,
      creditCalls,
      codLedgerInserts,
      walletLedgerInserts,
      getBalances: () => ({ walletBalance, codDue }),
    };
  }

  it('replays all-COD settlement via source_txn_id without decreasing COD again', async () => {
    const { service, repo, decreaseCalls, creditCalls } = makeService({
      codDue: '40.00',
      existingCodLedger: true,
    });

    const result = await service.applyVerifiedWalletTopUp(
      {
        paymentTransactionId: PAYMENT_TX_ID,
        riderProfileId: RIDER_ID,
        amount: '40.00',
      },
      {} as never,
    );

    expect(result.idempotent_replay).toBe(true);
    expect(result.wallet_ledger_id).toBeNull();
    expect(decreaseCalls).toHaveLength(0);
    expect(creditCalls).toHaveLength(0);
    expect(repo.insertCodLedger).not.toHaveBeenCalled();
    expect(repo.insertWalletLedger).not.toHaveBeenCalled();
  });

  it('settles all-COD top-up once then replays on the second call', async () => {
    const { service, decreaseCalls, creditCalls, codLedgerInserts, walletLedgerInserts } =
      makeService({ codDue: '50.00' });

    const first = await service.applyVerifiedWalletTopUp(
      {
        paymentTransactionId: PAYMENT_TX_ID,
        riderProfileId: RIDER_ID,
        amount: '40.00',
      },
      {} as never,
    );
    const second = await service.applyVerifiedWalletTopUp(
      {
        paymentTransactionId: PAYMENT_TX_ID,
        riderProfileId: RIDER_ID,
        amount: '40.00',
      },
      {} as never,
    );

    expect(first.idempotent_replay).toBe(false);
    expect(first.wallet_ledger_id).toBeNull();
    expect(first).toMatchObject({
      settled_against_cod: '40.00',
      wallet_credited: '0.00',
      cod_ledger_id: 'cod-ledger-1',
    });
    expect(decreaseCalls).toEqual(['40.00']);
    expect(creditCalls).toHaveLength(0);
    expect(codLedgerInserts).toHaveLength(1);
    expect(codLedgerInserts[0].sourceTxnId).toBe(SOURCE_TXN_ID);
    expect(walletLedgerInserts).toHaveLength(0);
    expect(second.idempotent_replay).toBe(true);
    expect(decreaseCalls).toHaveLength(1);
  });

  it('credits wallet remainder once when COD due is lower than the top-up', async () => {
    const { service, decreaseCalls, creditCalls, walletLedgerInserts } = makeService({
      codDue: '10.00',
    });

    const first = await service.applyVerifiedWalletTopUp(
      {
        paymentTransactionId: PAYMENT_TX_ID,
        riderProfileId: RIDER_ID,
        amount: '40.00',
      },
      {} as never,
    );
    const second = await service.applyVerifiedWalletTopUp(
      {
        paymentTransactionId: PAYMENT_TX_ID,
        riderProfileId: RIDER_ID,
        amount: '40.00',
      },
      {} as never,
    );

    expect(first.idempotent_replay).toBe(false);
    expect(decreaseCalls).toEqual(['10.00']);
    expect(creditCalls).toEqual(['30.00']);
    expect(walletLedgerInserts).toHaveLength(1);
    expect(walletLedgerInserts[0].relatedPaymentTransactionId).toBe(PAYMENT_TX_ID);
    expect(second.idempotent_replay).toBe(true);
    expect(decreaseCalls).toHaveLength(1);
    expect(creditCalls).toHaveLength(1);
  });

  it('stops before wallet credit when COD ledger insert fails (caller must roll back)', async () => {
    const { service, creditCalls, decreaseCalls } = makeService({
      codDue: '40.00',
      failOn: 'insertCodLedger',
    });

    await expect(
      service.applyVerifiedWalletTopUp(
        {
          paymentTransactionId: PAYMENT_TX_ID,
          riderProfileId: RIDER_ID,
          amount: '40.00',
        },
        {} as never,
      ),
    ).rejects.toThrow('cod ledger insert failed');

    expect(decreaseCalls).toEqual(['40.00']);
    expect(creditCalls).toHaveLength(0);
  });

  it('does not leave a partial split when wallet ledger insert fails after COD decrease', async () => {
    const { service, creditCalls, decreaseCalls, getBalances } = makeService({
      codDue: '10.00',
      failOn: 'insertWalletLedger',
    });

    await expect(
      service.applyVerifiedWalletTopUp(
        {
          paymentTransactionId: PAYMENT_TX_ID,
          riderProfileId: RIDER_ID,
          amount: '40.00',
        },
        {} as never,
      ),
    ).rejects.toThrow('wallet ledger insert failed');

    // In production the surrounding DB transaction rolls these writes back.
    // The unit mock shows the failure happens after both money moves, which is
    // why the settle path must stay inside one postgres.transaction.
    expect(decreaseCalls).toEqual(['10.00']);
    expect(creditCalls).toEqual(['30.00']);
    expect(getBalances()).toEqual({ walletBalance: '30.00', codDue: '0.00' });
  });
});
