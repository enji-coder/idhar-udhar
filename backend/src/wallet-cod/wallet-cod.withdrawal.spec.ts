import { WalletCodService } from './wallet-cod.service';

describe('WalletCodService withdrawal lifecycle', () => {
  const riderId = '11111111-1111-1111-1111-111111111111';
  const withdrawalId = '22222222-2222-2222-2222-222222222222';
  const adminAuth = {
    role: 'ADMIN',
    identityId: 'admin-id',
    profileId: 'admin-profile',
  } as never;

  function makeService(overrides?: {
    withdrawal?: Record<string, unknown>;
    initiate?: {
      outcome: 'accepted' | 'rejected';
      providerTransferId: string | null;
      providerStatus: string | null;
      failureReason: string | null;
    };
    retrieve?: {
      outcome: 'success' | 'failed' | 'pending' | 'reversed' | 'unknown';
      providerTransferId: string | null;
      providerStatus: string | null;
      failureReason: string | null;
    };
  }) {
    const withdrawal: Record<string, unknown> = {
      withdrawal_id: withdrawalId,
      rider_profile_id: riderId,
      amount: '10.00',
      status: 'REQUESTED',
      payout_method: 'UPI',
      rider_upi_id: 'upi-1',
      bank_account_id: null,
      wallet_ledger_id: 'ledger-debit',
      merchant_transfer_id: null,
      provider_transfer_id: null,
      provider_status: null,
      failure_reason: null,
      refund_wallet_ledger_id: null,
      ...overrides?.withdrawal,
    };
    const events: string[] = [];
    const repo = {
      lockWithdrawal: jest.fn(async () => ({ ...withdrawal })),
      findWithdrawalByMerchantTransferId: jest.fn(async () => ({
        withdrawal_id: withdrawalId,
      })),
      findUpiById: jest.fn(async () => ({
        rider_upi_id: 'upi-1',
        vpa_encrypted_or_token: 'rider@upi',
        vpa_masked: 'r***@upi',
      })),
      findBankById: jest.fn(async () => null),
      lockAccounts: jest.fn(async () => ({
        wallet: {
          wallet_account_id: 'wallet-1',
          available_balance: '40.00',
        },
        cod: { cod_account_id: 'cod-1', cod_due: '0.00' },
        threshold: '100.00',
      })),
      creditWallet: jest.fn(async () => '50.00'),
      insertWalletLedger: jest.fn(async () => ({
        wallet_ledger_id: 'ledger-refund',
      })),
      updateWithdrawalStatus: jest.fn(async (input: Record<string, unknown>) => {
        if (typeof input.status === 'string') {
          withdrawal.status = input.status;
        }
        if (typeof input.refundWalletLedgerId === 'string') {
          withdrawal.refund_wallet_ledger_id = input.refundWalletLedgerId;
        }
        if (typeof input.merchantTransferId === 'string') {
          withdrawal.merchant_transfer_id = input.merchantTransferId;
        }
        if (typeof input.providerTransferId === 'string') {
          withdrawal.provider_transfer_id = input.providerTransferId;
        }
      }),
      listWithdrawals: jest.fn(async () => []),
      listProcessingForReconcile: jest.fn(async () => []),
    };
    const identities = {
      findAdminProfile: jest.fn(async () => ({
        admin_profile_id: 'admin-profile',
        finance_access: true,
      })),
    };
    const walletNotifications = {
      onWithdrawalEvent: jest.fn(async (input: { type: string }) => {
        events.push(input.type);
      }),
      onWithdrawalRequested: jest.fn(),
    };
    const cashfree = {
      initiatePayoutTransfer: jest.fn(
        async () =>
          overrides?.initiate ?? {
            outcome: 'accepted',
            providerTransferId: 'cf-1',
            providerStatus: 'PENDING',
            failureReason: null,
          },
      ),
      retrievePayoutTransfer: jest.fn(
        async () =>
          overrides?.retrieve ?? {
            outcome: 'pending',
            providerTransferId: 'cf-1',
            providerStatus: 'PENDING',
            failureReason: null,
          },
      ),
    };
    const config = {
      getOrThrow: () => ({
        provider: 'cashfree',
        cashfree: { environment: 'sandbox' },
        payoutReconcile: {
          workerEnabled: false,
          pollMs: 30000,
          minAgeSeconds: 60,
          batchSize: 20,
        },
      }),
    };
    const postgres = {
      transaction: async (fn: (tx: unknown) => Promise<unknown>) => fn({}),
    };
    const service = new WalletCodService(
      postgres as never,
      repo as never,
      {} as never,
      identities as never,
      walletNotifications as never,
      cashfree as never,
      config as never,
      { warn: jest.fn(), info: jest.fn() } as never,
    );
    return { service, repo, cashfree, events, withdrawal };
  }

  it('moves REQUESTED to PROCESSING and initiates payout once', async () => {
    const { service, cashfree, events } = makeService();
    const result = await service.markWithdrawalProcessing(adminAuth, withdrawalId);
    expect(result.status).toBe('PROCESSING');
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledTimes(1);
    expect(events).toContain('WITHDRAWAL_PROCESSING');
  });

  it('marks SUCCESSFUL from authoritative provider success without refunding', async () => {
    const { service, repo, events } = makeService({
      withdrawal: { status: 'PROCESSING', merchant_transfer_id: 'w1' },
    });
    const result = await service.applyAuthoritativePayoutOutcome({
      withdrawalId,
      outcome: 'success',
      providerTransferId: 'cf-1',
      providerStatus: 'SUCCESS',
      failureReason: null,
    });
    expect(result).toEqual({ status: 'SUCCESSFUL', result: 'applied' });
    expect(repo.creditWallet).not.toHaveBeenCalled();
    expect(events).toContain('WITHDRAWAL_SUCCESSFUL');
  });

  it('refunds exactly once on FAILED and ignores repeated failure', async () => {
    const { service, repo, events } = makeService({
      withdrawal: { status: 'PROCESSING', merchant_transfer_id: 'w1' },
    });
    const first = await service.applyAuthoritativePayoutOutcome({
      withdrawalId,
      outcome: 'failed',
      providerTransferId: 'cf-1',
      providerStatus: 'FAILED',
      failureReason: 'Bank rejected',
    });
    expect(first.status).toBe('FAILED');
    expect(repo.creditWallet).toHaveBeenCalledTimes(1);
    expect(events).toContain('WITHDRAWAL_FAILED');

    const second = await service.applyAuthoritativePayoutOutcome({
      withdrawalId,
      outcome: 'failed',
      providerTransferId: 'cf-1',
      providerStatus: 'FAILED',
      failureReason: 'Bank rejected',
    });
    expect(second.result).toBe('duplicate');
    expect(repo.creditWallet).toHaveBeenCalledTimes(1);
  });

  it('ignores repeated SUCCESS callbacks', async () => {
    const { service, events } = makeService({
      withdrawal: {
        status: 'SUCCESSFUL',
        merchant_transfer_id: 'w1',
        provider_transfer_id: 'cf-1',
      },
    });
    const result = await service.applyAuthoritativePayoutOutcome({
      withdrawalId,
      outcome: 'success',
      providerTransferId: 'cf-1',
      providerStatus: 'SUCCESS',
      failureReason: null,
    });
    expect(result.result).toBe('duplicate');
    expect(events).not.toContain('WITHDRAWAL_SUCCESSFUL');
  });

  it('does not refund when reconcile status is unknown', async () => {
    const { service, repo } = makeService({
      withdrawal: {
        status: 'PROCESSING',
        merchant_transfer_id: 'w1',
      },
      retrieve: {
        outcome: 'unknown',
        providerTransferId: null,
        providerStatus: null,
        failureReason: 'Transfer was not found at Cashfree',
      },
    });
    const result = await service.reconcileWithdrawal(withdrawalId);
    expect(result.result).toBe('requires_review');
    expect(repo.creditWallet).not.toHaveBeenCalled();
  });

  it('rejects REQUESTED with a single refund notification', async () => {
    const { service, repo, events } = makeService();
    const result = await service.rejectWithdrawal(adminAuth, withdrawalId, 'docs');
    expect(result.status).toBe('REJECTED');
    expect(repo.creditWallet).toHaveBeenCalledTimes(1);
    expect(events).toContain('WITHDRAWAL_REJECTED');
  });
});
