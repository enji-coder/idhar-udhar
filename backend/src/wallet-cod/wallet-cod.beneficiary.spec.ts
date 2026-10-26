import { WalletCodService } from './wallet-cod.service';
import { encryptPayoutInstrument, payoutBeneficiaryId } from './payout-instrument-crypto';
import { TRANSFER_CLAIMED, TRANSFER_NOT_SENT } from './payout-transfer-state';

const instrumentKey = Buffer.alloc(32, 7);
const storedVpa = encryptPayoutInstrument('rider@upi', instrumentKey);
const storedAccount = encryptPayoutInstrument('123456789012', instrumentKey);

describe('Cashfree beneficiary gate', () => {
  const riderId = '11111111-1111-4111-8111-111111111111';
  const upiRowId = '33333333-3333-4333-8333-333333333333';
  const bankRowId = '44444444-4444-4444-8444-444444444444';
  const withdrawalId = '22222222-2222-4222-8222-222222222222';
  const adminAuth = {
    role: 'ADMIN',
    identityId: 'admin-id',
    profileId: 'admin-profile',
  } as never;
  const upiBeneficiaryId = payoutBeneficiaryId('UPI', upiRowId);
  const bankBeneficiaryId = payoutBeneficiaryId('BANK', bankRowId);

  function makeService(input?: {
    method?: 'UPI' | 'BANK';
    gets?: Array<{ outcome: 'registered' | 'missing' | 'unknown'; beneficiaryId: string | null }>;
    register?: { outcome: 'registered' | 'duplicate' | 'rejected' | 'unknown'; beneficiaryId: string | null };
    transfer?: { outcome: 'accepted' | 'rejected'; providerTransferId: string | null; providerStatus: string | null; failureReason: string | null } | 'timeout';
    alreadyRegistered?: boolean;
  }) {
    const method = input?.method ?? 'UPI';
    const beneficiaryId = method === 'UPI' ? upiBeneficiaryId : bankBeneficiaryId;
    let storedId: string | null = input?.alreadyRegistered ? beneficiaryId : null;
    let storedStatus: string | null = input?.alreadyRegistered ? 'REGISTERED' : null;
    const withdrawal: Record<string, unknown> = {
      withdrawal_id: withdrawalId,
      rider_profile_id: riderId,
      amount: '10.00',
      status: 'REQUESTED',
      payout_method: method,
      rider_upi_id: method === 'UPI' ? upiRowId : null,
      bank_account_id: method === 'BANK' ? bankRowId : null,
      wallet_ledger_id: 'ledger-debit',
      merchant_transfer_id: null,
      provider_transfer_id: null,
      provider_status: null,
      failure_reason: null,
      refund_wallet_ledger_id: null,
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
        vpa_encrypted_or_token: storedVpa,
        vpa_masked: 'r***@upi',
        cashfree_beneficiary_id: storedId,
        cashfree_beneficiary_status: storedStatus,
      })),
      findBankById: jest.fn(async () => ({
        bank_account_id: bankRowId,
        account_encrypted_or_token: storedAccount,
        account_masked: 'XXXXXX9012',
        ifsc_or_bank: 'HDFC0001234',
        holder_name: 'Ravi Kumar',
        cashfree_beneficiary_id: storedId,
        cashfree_beneficiary_status: storedStatus,
      })),
      saveUpiBeneficiary: jest.fn(async (_id: string, id: string, status: string) => {
        storedId = id;
        storedStatus = status;
      }),
      saveBankBeneficiary: jest.fn(async (_id: string, id: string, status: string) => {
        storedId = id;
        storedStatus = status;
      }),
      lockAccounts: jest.fn(async () => ({
        wallet: { wallet_account_id: 'wallet-1', available_balance: '40.00' },
        cod: { cod_account_id: 'cod-1', cod_due: '0.00' },
        threshold: '100.00',
      })),
      creditWallet: jest.fn(async () => '50.00'),
      insertWalletLedger: jest.fn(async () => ({ wallet_ledger_id: 'ledger-refund' })),
    };
    const gets = [...(input?.gets ?? [{ outcome: 'missing' as const, beneficiaryId: null }, { outcome: 'registered' as const, beneficiaryId }])];
    const cashfree = {
      getPayoutBeneficiary: jest.fn(async () => gets.shift() ?? { outcome: 'unknown', beneficiaryId: null }),
      registerPayoutBeneficiary: jest.fn(async () => input?.register ?? { outcome: 'registered', beneficiaryId }),
      initiatePayoutTransfer: jest.fn(async () => {
        if (input?.transfer === 'timeout') {
          throw new Error('timeout');
        }
        return (
          input?.transfer ?? {
            outcome: 'accepted',
            providerTransferId: 'cf-1',
            providerStatus: 'PENDING',
            failureReason: null,
          }
        );
      }),
      retrievePayoutTransfer: jest.fn(),
    };
    const service = new WalletCodService(
      { transaction: async (fn: (tx: unknown) => Promise<unknown>) => fn({}) } as never,
      repo as never,
      {} as never,
      {
        findAdminProfile: jest.fn(async () => ({
          admin_profile_id: 'admin-profile',
          finance_access: true,
        })),
        findRiderDriver: jest.fn(async () => ({ name: 'Ravi Kumar' })),
      } as never,
      { onWithdrawalEvent: jest.fn(async () => undefined), onWithdrawalRequested: jest.fn() } as never,
      cashfree as never,
      {
        getOrThrow: () => ({
          provider: 'cashfree',
          payoutInstrumentKey: instrumentKey.toString('base64'),
          payoutReconcile: { workerEnabled: false, pollMs: 30000, minAgeSeconds: 60, batchSize: 20 },
        }),
      } as never,
      {} as never,
      { warn: jest.fn(), info: jest.fn() } as never,
    );
    return { service, repo, cashfree };
  }

  it('transfers only after Cashfree confirms the UPI beneficiary', async () => {
    const { service, cashfree } = makeService();
    const result = await service.markWithdrawalProcessing(adminAuth, withdrawalId);
    expect(result.status).toBe('PROCESSING');
    expect(cashfree.registerPayoutBeneficiary).toHaveBeenCalledWith(
      expect.objectContaining({
        beneficiaryId: upiBeneficiaryId,
        beneficiaryName: 'Ravi Kumar',
        payoutMethod: 'UPI',
        vpa: 'rider@upi',
      }),
    );
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledTimes(1);
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledWith(
      expect.objectContaining({
        beneficiaryId: upiBeneficiaryId,
        payoutMethod: 'UPI',
        vpa: 'rider@upi',
        bankAccountNumber: null,
      }),
    );
  });

  it('reuses a duplicate registration after a confirming lookup and transfers once', async () => {
    const { service, cashfree } = makeService({
      register: { outcome: 'duplicate', beneficiaryId: upiBeneficiaryId },
    });
    await service.markWithdrawalProcessing(adminAuth, withdrawalId);
    expect(cashfree.registerPayoutBeneficiary).toHaveBeenCalledTimes(1);
    expect(cashfree.getPayoutBeneficiary).toHaveBeenCalledTimes(2);
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledTimes(1);
  });

  it('does not transfer or refund when beneficiary lookup times out', async () => {
    const { service, cashfree, repo } = makeService({
      gets: [{ outcome: 'unknown', beneficiaryId: null }],
    });
    const result = await service.markWithdrawalProcessing(adminAuth, withdrawalId);
    expect(result.status).toBe('PROCESSING');
    expect(cashfree.registerPayoutBeneficiary).not.toHaveBeenCalled();
    expect(cashfree.initiatePayoutTransfer).not.toHaveBeenCalled();
    expect(repo.creditWallet).not.toHaveBeenCalled();
  });

  it('does not transfer or refund when beneficiary creation times out', async () => {
    const { service, cashfree, repo } = makeService({
      register: { outcome: 'unknown', beneficiaryId: null },
    });
    const result = await service.markWithdrawalProcessing(adminAuth, withdrawalId);
    expect(result.status).toBe('PROCESSING');
    expect(cashfree.initiatePayoutTransfer).not.toHaveBeenCalled();
    expect(repo.creditWallet).not.toHaveBeenCalled();
  });

  it('does not refund when a confirmed transfer times out', async () => {
    const { service, cashfree, repo } = makeService({
      alreadyRegistered: true,
      transfer: 'timeout',
    });
    const result = await service.markWithdrawalProcessing(adminAuth, withdrawalId);
    expect(result.status).toBe('PROCESSING');
    expect(cashfree.registerPayoutBeneficiary).not.toHaveBeenCalled();
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledTimes(1);
    expect(repo.creditWallet).not.toHaveBeenCalled();
  });

  it('sends a bank transfer with the bank instrument and not the UPI instrument', async () => {
    const { service, cashfree } = makeService({ method: 'BANK' });
    await service.markWithdrawalProcessing(adminAuth, withdrawalId);
    expect(cashfree.initiatePayoutTransfer).toHaveBeenCalledWith(
      expect.objectContaining({
        beneficiaryId: bankBeneficiaryId,
        payoutMethod: 'BANK',
        vpa: null,
        bankAccountNumber: '123456789012',
        bankIfsc: 'HDFC0001234',
      }),
    );
  });
});
