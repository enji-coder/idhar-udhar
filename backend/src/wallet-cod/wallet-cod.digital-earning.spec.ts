import { OrderRow } from '../orders/orders.repository';
import { WalletCodService } from './wallet-cod.service';

const ORDER_ID = '55555555-5555-4555-8555-555555555555';
const RIDER_ID = '22222222-2222-4222-8222-222222222222';
const SNAP_ID = '77777777-7777-4777-8777-777777777777';

function orderWithStatus(canonicalStatus: string): OrderRow {
  return {
    order_id: ORDER_ID,
    rider_profile_id: RIDER_ID,
    canonical_status: canonicalStatus,
  } as OrderRow;
}

function deliveredOrder(): OrderRow {
  return orderWithStatus('DELIVERED');
}

function digitalPlan() {
  return { planned_online: '100.00', planned_cash: '0.00' };
}

describe('WalletCodService digital earning gate', () => {
  function makeService(input?: {
    plan?: { planned_online: string; planned_cash: string } | null;
    verifiedPaid?: string;
    cashCollected?: string;
    alreadyEarned?: boolean;
    lockedCanonicalStatus?: string;
  }) {
    let earned = input?.alreadyEarned ?? false;
    const earnings: Array<{ amount: string; entryType: string }> = [];
    const codIncreases: Array<{ amount: string; source: string }> = [];
    const lockedStatus = input?.lockedCanonicalStatus ?? 'DELIVERED';
    const repo = {
      findOriginalSnapshot: jest.fn(async () => ({
        finance_snapshot_id: SNAP_ID,
        rider_amount: '85.00',
        company_commission_amount: '15.00',
        trip_fare: '100.00',
      })),
      lockAccounts: jest.fn(async () => ({
        wallet: { wallet_account_id: 'wallet-1', available_balance: '0.00' },
        cod: { cod_account_id: 'cod-1', cod_due: '0.00' },
        threshold: '500.00',
      })),
      cashCollected: jest.fn(async () => input?.cashCollected ?? '0.00'),
      findOrderPaymentPlan: jest.fn(async () =>
        input && 'plan' in input ? input.plan : digitalPlan(),
      ),
      verifiedOnlineBookingPaid: jest.fn(async () => input?.verifiedPaid ?? '0.00'),
      isPositive: jest.fn(async (amount: string) => Number(amount) > 0),
      companyDueFromCash: jest.fn(async () => '15.00'),
      postedCashCompanyShare: jest.fn(async () => '0.00'),
      exceeds: jest.fn(async (left: string, right: string) => Number(left) > Number(right)),
      subtract: jest.fn(async () => '15.00'),
      increaseCod: jest.fn(async () => undefined),
      insertCodLedger: jest.fn(async (row: { amount: string; source: string }) => {
        codIncreases.push(row);
        return { cod_ledger_id: 'cod-ledger-1' };
      }),
      hasWalletEarningForOrder: jest.fn(async () => earned),
      hasWalletCompanyShareForOrder: jest.fn(async () => false),
      debitWalletAllowingNegative: jest.fn(async () => '0.00'),
      hasDigitalEarningSettlement: jest.fn(async () => false),
      decreaseCod: jest.fn(async () => '0.00'),
      splitInflow: jest.fn(async (amount: string) => ({
        settle: '0.00',
        remainder: amount,
      })),
      creditWallet: jest.fn(async () => '85.00'),
      insertWalletLedger: jest.fn(async (row: { amount: string; entryType: string }) => {
        earned = true;
        earnings.push(row);
        return { wallet_ledger_id: 'wallet-ledger-1' };
      }),
      operationalStatus: jest.fn(async () => 'ACTIVE'),
      syncOperationalStatus: jest.fn(async () => 'ACTIVE'),
      walletLedgerNet: jest.fn(async () => '85.00'),
      codLedgerNet: jest.fn(async () => '0.00'),
    };
    const onOperationalStatusChange = jest.fn(async () => undefined);
    const lockById = jest.fn(async () => orderWithStatus(lockedStatus));
    const service = new WalletCodService(
      {} as never,
      repo as never,
      {} as never,
      {} as never,
      { onOperationalStatusChange } as never,
      {} as never,
      { getOrThrow: () => ({}) } as never,
      { lockById } as never,
      { info: jest.fn(), warn: jest.fn() } as never,
    );
    return { service, repo, earnings, codIncreases, onOperationalStatusChange, lockById };
  }

  it('posts the frozen rider amount once when a digital trip is paid and delivered', async () => {
    const { service, earnings } = makeService({ verifiedPaid: '100.00' });
    await service.syncOrderFinance(deliveredOrder(), {} as never);
    await service.syncOrderFinance(deliveredOrder(), {} as never);
    expect(earnings).toEqual([
      expect.objectContaining({
        amount: '85.00',
        entryType: 'EARNING',
        relatedOrderId: ORDER_ID,
      }),
    ]);
  });

  it('does not post an earning when the online booking charge is still pending', async () => {
    const { service, earnings, repo } = makeService({ verifiedPaid: '0.00' });
    await service.syncOrderFinance(deliveredOrder(), {} as never);
    expect(earnings).toEqual([]);
    expect(repo.creditWallet).not.toHaveBeenCalled();
  });

  it('does not post an earning when the verified booking charge is missing or partial', async () => {
    const missing = makeService({ verifiedPaid: '0.00' });
    await missing.service.syncOrderFinance(deliveredOrder(), {} as never);
    expect(missing.earnings).toEqual([]);

    const partial = makeService({ verifiedPaid: '40.00' });
    await partial.service.syncOrderFinance(deliveredOrder(), {} as never);
    expect(partial.earnings).toEqual([]);
    expect(partial.repo.creditWallet).not.toHaveBeenCalled();
  });

  it('does not treat a missing payment plan as a paid digital trip', async () => {
    const { service, earnings, repo } = makeService({ plan: null, verifiedPaid: '100.00' });
    await service.syncOrderFinance(deliveredOrder(), {} as never);
    expect(earnings).toEqual([]);
    expect(repo.verifiedOnlineBookingPaid).not.toHaveBeenCalled();
    expect(repo.increaseCod).not.toHaveBeenCalled();
  });

  it('debits the company share from the wallet once and does not credit a cash trip', async () => {
    let debited = false;
    const { service, earnings, codIncreases, repo } = makeService({
      plan: { planned_online: '0.00', planned_cash: '100.00' },
      cashCollected: '100.00',
      verifiedPaid: '0.00',
    });
    repo.debitWalletAllowingNegative.mockResolvedValue('-15.00');
    repo.walletLedgerNet.mockResolvedValue('-15.00');
    repo.hasWalletCompanyShareForOrder.mockImplementation(async () => debited);
    repo.insertWalletLedger.mockImplementation(async (row: { amount: string; entryType: string }) => {
      debited = true;
      earnings.push(row);
      return { wallet_ledger_id: 'wallet-ledger-1' };
    });
    await service.syncOrderFinance(deliveredOrder(), {} as never);
    await service.syncOrderFinance(deliveredOrder(), {} as never);
    expect(repo.creditWallet).not.toHaveBeenCalled();
    expect(repo.increaseCod).not.toHaveBeenCalled();
    expect(codIncreases).toEqual([]);
    expect(earnings).toEqual([
      expect.objectContaining({
        amount: '15.00',
        entryType: 'COMPANY_SHARE',
        direction: 'DEBIT',
        relatedOrderId: ORDER_ID,
      }),
    ]);
  });

  it('does not post COD company share when locked order is not DELIVERED', async () => {
    const { service, earnings, codIncreases, repo, onOperationalStatusChange, lockById } =
      makeService({
        plan: { planned_online: '0.00', planned_cash: '100.00' },
        cashCollected: '100.00',
        verifiedPaid: '0.00',
        lockedCanonicalStatus: 'IN_TRANSIT',
      });
    await service.syncOrderFinance(orderWithStatus('IN_TRANSIT'), {} as never);
    expect(lockById).toHaveBeenCalled();
    expect(codIncreases).toEqual([]);
    expect(repo.increaseCod).not.toHaveBeenCalled();
    expect(repo.debitWalletAllowingNegative).not.toHaveBeenCalled();
    expect(repo.insertCodLedger).not.toHaveBeenCalled();
    expect(earnings).toEqual([]);
    expect(repo.creditWallet).not.toHaveBeenCalled();
    expect(repo.syncOperationalStatus).toHaveBeenCalled();
    expect(onOperationalStatusChange).toHaveBeenCalled();
  });

  it('applies an online earning to COD Due once and does not credit the wallet', async () => {
    let settled = false;
    const { service, earnings, repo } = makeService({ verifiedPaid: '100.00' });
    repo.lockAccounts.mockImplementation(async () => ({
      wallet: { wallet_account_id: 'wallet-1', available_balance: '0.00' },
      cod: { cod_account_id: 'cod-1', cod_due: '85.00' },
      threshold: '500.00',
    }));
    repo.splitInflow.mockImplementation(async () => ({
      settle: '85.00',
      remainder: '0.00',
    }));
    repo.hasDigitalEarningSettlement.mockImplementation(async () => settled);
    repo.insertCodLedger.mockImplementation(async (row: { source: string }) => {
      if (row.source === 'DIGITAL_EARNING_SETTLEMENT') {
        settled = true;
      }
      return { cod_ledger_id: 'cod-ledger-1' };
    });
    repo.walletLedgerNet.mockImplementation(async () => '0.00');
    repo.codLedgerNet.mockImplementation(async () => '0.00');

    await service.syncOrderFinance(deliveredOrder(), {} as never);
    await service.syncOrderFinance(deliveredOrder(), {} as never);

    expect(earnings).toEqual([]);
    expect(repo.creditWallet).not.toHaveBeenCalled();
    expect(repo.decreaseCod).toHaveBeenCalledTimes(1);
    expect(repo.insertCodLedger).toHaveBeenCalledTimes(1);
    expect(repo.insertCodLedger).toHaveBeenCalledWith(
      expect.objectContaining({
        amount: '85.00',
        source: 'DIGITAL_EARNING_SETTLEMENT',
        relatedOrderId: ORDER_ID,
      }),
      expect.anything(),
    );
  });

  it('debits ₹18.60 once when a ₹124.00 cash fare is collected', async () => {
    let debited = false;
    const { service, repo } = makeService({
      plan: { planned_online: '0.00', planned_cash: '124.00' },
      cashCollected: '124.00',
    });
    repo.companyDueFromCash.mockResolvedValue('18.60');
    repo.debitWalletAllowingNegative.mockResolvedValue('-18.60');
    repo.walletLedgerNet.mockResolvedValue('-18.60');
    repo.hasWalletCompanyShareForOrder.mockImplementation(async () => debited);
    const debits: Array<{ amount: string; entryType: string }> = [];
    repo.insertWalletLedger.mockImplementation(async (row: { amount: string; entryType: string }) => {
      debited = true;
      debits.push(row);
      return { wallet_ledger_id: 'wallet-ledger-1' };
    });

    await service.syncOrderFinance(deliveredOrder(), {} as never);
    await service.syncOrderFinance(deliveredOrder(), {} as never);

    expect(repo.creditWallet).not.toHaveBeenCalled();
    expect(repo.increaseCod).not.toHaveBeenCalled();
    expect(debits).toEqual([
      expect.objectContaining({
        amount: '18.60',
        entryType: 'COMPANY_SHARE',
        direction: 'DEBIT',
      }),
    ]);
    expect(repo.debitWalletAllowingNegative).toHaveBeenCalledTimes(1);
  });

  it('does not debit the wallet when a historical COD company share already exists', async () => {
    const { service, repo } = makeService({
      plan: { planned_online: '0.00', planned_cash: '124.00' },
      cashCollected: '124.00',
    });
    repo.companyDueFromCash.mockResolvedValue('18.60');
    repo.postedCashCompanyShare.mockResolvedValue('18.60');

    await service.syncOrderFinance(deliveredOrder(), {} as never);

    expect(repo.debitWalletAllowingNegative).not.toHaveBeenCalled();
    expect(repo.increaseCod).not.toHaveBeenCalled();
    expect(repo.creditWallet).not.toHaveBeenCalled();
  });

  it('does not post online rider earning when locked order is not DELIVERED', async () => {
    const { service, earnings, codIncreases, repo, onOperationalStatusChange, lockById } =
      makeService({
        verifiedPaid: '100.00',
        lockedCanonicalStatus: 'PICKED_UP',
      });
    await service.syncOrderFinance(orderWithStatus('PICKED_UP'), {} as never);
    expect(lockById).toHaveBeenCalled();
    expect(earnings).toEqual([]);
    expect(repo.creditWallet).not.toHaveBeenCalled();
    expect(repo.insertWalletLedger).not.toHaveBeenCalled();
    expect(codIncreases).toEqual([]);
    expect(repo.increaseCod).not.toHaveBeenCalled();
    expect(repo.syncOperationalStatus).toHaveBeenCalled();
    expect(onOperationalStatusChange).toHaveBeenCalled();
  });
});
