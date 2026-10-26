import { ApiError } from '../common/errors/api-error';
import { PayoutTransferNotDispatchedError } from '../payments/cashfree-payment.service';
import { encryptPayoutInstrument, payoutBeneficiaryId } from './payout-instrument-crypto';
import {
  CLAIM_PAYOUT_TRANSFER_SQL,
  RELEASE_PAYOUT_TRANSFER_SQL,
  TRANSFER_CLAIMED,
  TRANSFER_NOT_SENT,
} from './payout-transfer-state';
import { WalletCodService } from './wallet-cod.service';

describe('payout transfer claim', () => {
  it('lets only a confirmed unsent withdrawal become a single dispatch claim', () => {
    expect(CLAIM_PAYOUT_TRANSFER_SQL).toContain(`provider_status = '${TRANSFER_CLAIMED}'`);
    expect(CLAIM_PAYOUT_TRANSFER_SQL).toContain(`provider_status = '${TRANSFER_NOT_SENT}'`);
    expect(CLAIM_PAYOUT_TRANSFER_SQL).toContain('provider_transfer_id IS NULL');
    expect(CLAIM_PAYOUT_TRANSFER_SQL).toContain("status = 'PROCESSING'");
    expect(RELEASE_PAYOUT_TRANSFER_SQL).toContain(`provider_status = '${TRANSFER_NOT_SENT}'`);
    expect(RELEASE_PAYOUT_TRANSFER_SQL).toContain(`provider_status = '${TRANSFER_CLAIMED}'`);
    expect(RELEASE_PAYOUT_TRANSFER_SQL).toContain('provider_transfer_id IS NULL');
  });
});

describe('Cashfree payout safety', () => {
  const riderId = '11111111-1111-4111-8111-111111111111';
  const upiRowId = '33333333-3333-4333-8333-333333333333';
  const withdrawalId = '22222222-2222-4222-8222-222222222222';
  const adminAuth = {
    role: 'ADMIN',
    identityId: 'admin-id',
    profileId: 'admin-profile',
  } as never;
  const riderAuth = {
    role: 'RIDER',
    identityId: 'rider-id',
    profileId: riderId,
  } as never;
  const instrumentKey = Buffer.alloc(32, 8);
  const beneficiaryId = payoutBeneficiaryId('UPI', upiRowId);

  function makeService(input?: {
    driverName?: string | null;
    registered?: boolean;
    instrument?: string;
    initiate?: 'accept' | 'timeout' | 'not-sent' | 'reject';
    retrieve?: 'not_found' | 'throw' | 'success';
  }) {
    const withdrawal: Record<string, unknown> = {
      withdrawal_id: withdrawalId,
      rider_profile_id: riderId,
      amount: '10.00',
      status: 'REQUESTED',
      payout_method: 'UPI',
      rider_upi_id: upiRowId,
      bank_account_id: null,
      wallet_ledger_id: 'ledger-debit',
      merchant_transfer_id: null,
      provider_transfer_id: null,
      provider_status: null,
      failure_reason: null,
      refund_wallet_ledger_id: null,
    };
    let chain = Promise.resolve();
    const postgres = {
      transaction: (fn: (tx: unknown) => Promise<unknown>) => {
        const run = chain.then(() => fn({}));
        chain = run.then(
          () => undefined,
          () => undefined,
        );
        return run;
      },
    };
    const repo = {
      lockWithdrawal: jest.fn(async () => ({ ...withdrawal })),
      updateWithdrawalStatus: jest.fn(async (update: Record<string, unknown>) => {
        if (typeof update.status === 'string') withdrawal.status = update.status;
        if (typeof update.merchantTransferId === 'string') {
          withdrawal.merchant_transfer_id = update.merchantTransferId;
        }
        if (typeof update.providerStatus === 'string') {
          withdrawal.provider_status = update.providerStatus;
        }
        if (typeof update.providerTransferId === 'string') {
          withdrawal.provider_transfer_id = update.providerTransferId;
        }
        if (typeof update.refundWalletLedgerId === 'string') {
          withdrawal.refund_wallet_ledger_id = update.refundWalletLedgerId;
        }
        if (typeof update.failureReason === 'string') {
          withdrawal.failure_reason = update.failureReason;
        }
      }),
      claimPayoutTransferDispatch: jest.fn(async () => {
        if (withdrawal.status !== 'PROCESSING' || withdrawal.provider_transfer_id) {
          return false;
        }
        if (withdrawal.provider_status !== TRANSFER_NOT_SENT) {
          return false;
        }
        withdrawal.provider_status = TRANSFER_CLAIMED;
        return true;
      }),
      releasePayoutTransferDispatch: jest.fn(async () => {
        if (
          withdrawal.status !== 'PROCESSING' ||
          withdrawal.provider_transfer_id ||
          withdrawal.provider_status !== TRANSFER_CLAIMED
        ) {
          return false;
        }
        withdrawal.provider_status = TRANSFER_NOT_SENT;
        return true;
      }),
      findUpiById: jest.fn(async () => ({
        rider_upi_id: upiRowId,
        vpa_encrypted_or_token:
          input?.instrument ?? encryptPayoutInstrument('rider@upi', instrumentKey),
        vpa_masked: 'r***@upi',
        cashfree_beneficiary_id: input?.registered === false ? null : beneficiaryId,
        cashfree_beneficiary_status: input?.registered === false ? null : 'REGISTERED',
      })),
      findCurrentUpi: jest.fn(async () => ({
        rider_upi_id: upiRowId,
        vpa_encrypted_or_token:
          input?.instrument ?? encryptPayoutInstrument('rider@upi', instrumentKey),
        vpa_masked: 'r***@upi',
      })),
      findCurrentBankAccount: jest.fn(async () => null),
      saveUpiBeneficiary: jest.fn(async () => undefined),
      saveBankBeneficiary: jest.fn(async () => undefined),
      lockAccounts: jest.fn(async () => ({
        wallet: { wallet_account_id: 'wallet-1', available_balance: '40.00' },
        cod: { cod_account_id: 'cod-1', cod_due: '0.00' },
        threshold: '100.00',
      })),
      exceeds: jest.fn(async () => false),
      debitWallet: jest.fn(async () => '30.00'),
      creditWallet: jest.fn(async () => '40.00'),
      insertWalletLedger: jest.fn(async () => ({ wallet_ledger_id: 'ledger-refund' })),
      insertWithdrawal: jest.fn(async () => ({
        withdrawal_id: withdrawalId,
        status: 'REQUESTED',
      })),
    };
    let initiateCalls = 0;
    const cashfree = {
      getPayoutBeneficiary: jest.fn(async () => ({
        outcome: 'missing' as const,
        beneficiaryId: null,
      })),
      registerPayoutBeneficiary: jest.fn(async () => ({
        outcome: 'rejected' as const,
        beneficiaryId: null,
      })),
      initiatePayoutTransfer: jest.fn(async () => {
        initiateCalls += 1;
        if (input?.initiate === 'timeout') {
          throw new Error('timeout');
        }
        if (input?.initiate === 'not-sent' && initiateCalls === 1) {
          throw new PayoutTransferNotDispatchedError();
        }
        if (input?.initiate === 'reject') {
          return {
            outcome: 'rejected' as const,
            providerTransferId: null,
            providerStatus: 'REJECTED',
            failureReason: 'Cashfree rejected the payout transfer',
          };
        }
        return {
          outcome: 'accepted' as const,
          providerTransferId: 'cf-1',
          providerStatus: 'PENDING',
          failureReason: null,
        };
      }),
      retrievePayoutTransfer: jest.fn(async () => {
        if (input?.retrieve === 'throw') {
          throw new Error('socket timeout');
        }
        if (input?.retrieve === 'success') {
          return {
            outcome: 'success' as const,
            providerTransferId: 'cf-1',
            providerStatus: 'SUCCESS',
            failureReason: null,
          };
        }
        return {
          outcome: 'not_found' as const,
          providerTransferId: null,
          providerStatus: null,
          failureReason: 'Transfer was not found at Cashfree',
        };
      }),
    };
    const service = new WalletCodService(
      postgres as never,
      repo as never,
      { find: jest.fn(async () => null), insert: jest.fn(async () => undefined) } as never,
      {
        findAdminProfile: jest.fn(async () => ({
          admin_profile_id: 'admin-profile',
          finance_access: true,
        })),
        findRiderDriver: jest.fn(async () => ({
          name: input && 'driverName' in input ? input.driverName ?? null : 'Ravi Kumar',
        })),
      } as never,
      {
        onWithdrawalEvent: jest.fn(async () => undefined),
        onWithdrawalRequested: jest.fn(async () => undefined),
      } as never,
      cashfree as never,
      {
        getOrThrow: () => ({
          provider: 'cashfree',
          payoutInstrumentKey: instrumentKey.toString('base64'),
          payoutReconcile: {
            workerEnabled: false,
            pollMs: 30000,
            minAgeSeconds: 60,
            batchSize: 20,
          },
        }),
      } as never,
      {} as never,
      { warn: jest.fn(), info: jest.fn() } as never,
    );
    return { service, repo, cashfree, withdrawal };
  }

  function armProcessing(withdrawal: Record<string, unknown>, providerStatus: string | null) {
    withdrawal.status = 'PROCESSING';
    withdrawal.merchant_transfer_id = 'w-same';
    withdrawal.provider_status = providerStatus;
  }

  it('sends one transfer when two reconcilers see a confirmed non-creation', async () => {
    const { service, cashfree, withdrawal } = makeService({ retrieve: 'not_found' });
    armProcessing(withdrawal, TRANSFER_NOT_SENT);
    await Promise.all([
      service.reconcileWithdrawal(withdrawalId),
      service.reconcileWithdrawal(withdrawalId),
    ]);
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledTimes(1);
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledWith(
      expect.objectContaining({ merchantTransferId: 'w-same' }),
    );
  });

  it('does not send again after a 404 once a transfer attempt is ambiguous', async () => {
    const { service, cashfree, repo, withdrawal } = makeService({ retrieve: 'not_found' });
    armProcessing(withdrawal, TRANSFER_CLAIMED);
    const result = await service.reconcileWithdrawal(withdrawalId);
    expect(result).toEqual({ status: 'PROCESSING', result: 'requires_review' });
    expect(cashfree.initiatePayoutTransfer).not.toHaveBeenCalled();
    expect(repo.creditWallet).not.toHaveBeenCalled();
  });

  it('does not send again when an older processing row has no unsent marker', async () => {
    const { service, cashfree, repo, withdrawal } = makeService({ retrieve: 'not_found' });
    armProcessing(withdrawal, null);
    const result = await service.reconcileWithdrawal(withdrawalId);
    expect(result.result).toBe('requires_review');
    expect(cashfree.initiatePayoutTransfer).not.toHaveBeenCalled();
    expect(repo.creditWallet).not.toHaveBeenCalled();
  });

  it('does not send or refund when the transfer lookup transport fails', async () => {
    const { service, cashfree, repo, withdrawal } = makeService({ retrieve: 'throw' });
    armProcessing(withdrawal, TRANSFER_NOT_SENT);
    const result = await service.reconcileWithdrawal(withdrawalId);
    expect(result).toEqual({ status: 'PROCESSING', result: 'requires_review' });
    expect(cashfree.initiatePayoutTransfer).not.toHaveBeenCalled();
    expect(repo.creditWallet).not.toHaveBeenCalled();
  });

  it('retries once after a confirmed pre-dispatch failure and keeps the merchant id', async () => {
    const { service, cashfree, repo } = makeService({
      initiate: 'not-sent',
      retrieve: 'not_found',
    });
    const first = await service.markWithdrawalProcessing(adminAuth, withdrawalId);
    expect(first.status).toBe('PROCESSING');
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledTimes(1);
    expect(repo.creditWallet).not.toHaveBeenCalled();
    const second = await service.reconcileWithdrawal(withdrawalId);
    expect(second.status).toBe('PROCESSING');
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledTimes(2);
    const calls = cashfree.initiatePayoutTransfer.mock.calls as unknown as Array<
      [{ merchantTransferId: string }]
    >;
    expect(calls[0][0].merchantTransferId).toBe(calls[1][0].merchantTransferId);
    await service.reconcileWithdrawal(withdrawalId);
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledTimes(2);
  });

  it('keeps the debit after a timeout and does not post the transfer again', async () => {
    const { service, cashfree, repo } = makeService({
      initiate: 'timeout',
      retrieve: 'not_found',
    });
    const first = await service.markWithdrawalProcessing(adminAuth, withdrawalId);
    expect(first.status).toBe('PROCESSING');
    const second = await service.reconcileWithdrawal(withdrawalId);
    expect(second.result).toBe('requires_review');
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledTimes(1);
    expect(repo.creditWallet).not.toHaveBeenCalled();
  });

  it('refuses a UPI withdrawal before debit when the rider name is missing', async () => {
    const { service, repo } = makeService({ driverName: null });
    await expect(
      service.requestWithdraw(riderAuth, '10.00', 'UPI', 'idem-name'),
    ).rejects.toBeInstanceOf(ApiError);
    expect(repo.debitWallet).not.toHaveBeenCalled();
    expect(repo.insertWithdrawal).not.toHaveBeenCalled();
  });

  it('refuses a withdrawal of a legacy plaintext instrument before debit', async () => {
    const { service, repo } = makeService({ instrument: 'legacy-value' });
    await expect(
      service.requestWithdraw(riderAuth, '10.00', 'UPI', 'idem-legacy'),
    ).rejects.toMatchObject({ status: 409 });
    expect(repo.debitWallet).not.toHaveBeenCalled();
  });

  it('refunds an unsent processing withdrawal once when the name is missing', async () => {
    const { service, cashfree, repo, withdrawal } = makeService({
      registered: false,
      driverName: null,
      retrieve: 'not_found',
    });
    armProcessing(withdrawal, TRANSFER_NOT_SENT);
    const first = await service.reconcileWithdrawal(withdrawalId);
    expect(first).toEqual({ status: 'FAILED', result: 'applied' });
    expect(withdrawal.failure_reason).toBe('Beneficiary name is missing');
    expect(cashfree.initiatePayoutTransfer).not.toHaveBeenCalled();
    expect(repo.creditWallet).toHaveBeenCalledTimes(1);
    const second = await service.reconcileWithdrawal(withdrawalId);
    expect(second.result).toBe('ignored');
    expect(repo.creditWallet).toHaveBeenCalledTimes(1);
  });

  it('refunds one of two concurrent rejects of an unsent processing withdrawal', async () => {
    const { service, repo, withdrawal } = makeService();
    armProcessing(withdrawal, TRANSFER_NOT_SENT);
    const results = await Promise.allSettled([
      service.rejectWithdrawal(adminAuth, withdrawalId, 'name'),
      service.rejectWithdrawal(adminAuth, withdrawalId, 'name'),
    ]);
    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    expect(repo.creditWallet).toHaveBeenCalledTimes(1);
    expect(withdrawal.status).toBe('REJECTED');
  });

  it('does not refund a processing withdrawal whose transfer outcome is ambiguous', async () => {
    const { service, repo, withdrawal } = makeService();
    armProcessing(withdrawal, TRANSFER_CLAIMED);
    await expect(
      service.rejectWithdrawal(adminAuth, withdrawalId, 'stop'),
    ).rejects.toMatchObject({ status: 409 });
    expect(repo.creditWallet).not.toHaveBeenCalled();
    expect(withdrawal.status).toBe('PROCESSING');
  });

  it('does not refund an unreadable instrument while the transfer is still unsent', async () => {
    const wrong = encryptPayoutInstrument('rider@upi', Buffer.alloc(32, 1));
    const { service, repo, withdrawal } = makeService({
      instrument: wrong,
      retrieve: 'not_found',
    });
    armProcessing(withdrawal, TRANSFER_NOT_SENT);
    const result = await service.reconcileWithdrawal(withdrawalId);
    expect(result.status).toBe('PROCESSING');
    expect(repo.creditWallet).not.toHaveBeenCalled();
    expect(withdrawal.failure_reason).toBe(
      'Payout destination cannot be read with the configured key',
    );
    const rejected = await service.rejectWithdrawal(adminAuth, withdrawalId, 'unreadable');
    expect(rejected.status).toBe('REJECTED');
    expect(repo.creditWallet).toHaveBeenCalledTimes(1);
  });
});
