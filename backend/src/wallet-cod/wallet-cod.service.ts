import { Inject, Injectable, forwardRef } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository } from '../auth/identity/identity.repository';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AppLogger } from '../common/logger/app-logger';
import { isCheckViolation, isUniqueViolation } from '../common/pg-error';
import { AppConfig } from '../config/configuration';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { assertPositiveInr, formatInr } from '../fare/money';
import {
  hashRequest,
  IdempotencyRepository,
  IdempotencyScope,
} from '../orders/idempotency.repository';
import { OrderRow, OrdersRepository } from '../orders/orders.repository';
import {
  CashfreePaymentService,
  PayoutTransferNotDispatchedError,
} from '../payments/cashfree-payment.service';
import { WalletNotificationDispatcher } from '../notifications/wallet-notification.dispatcher';
import {
  LockedRiderFinance,
  serializeCodLedger,
  serializeEarning,
  serializeWalletLedger,
  WalletActorType,
  WalletCodRepository,
} from './wallet-cod.repository';
import {
  cashfreeBeneficiaryName,
  decryptPayoutInstrument,
  encryptPayoutInstrument,
  payoutBeneficiaryId,
} from './payout-instrument-crypto';
import {
  TRANSFER_NOT_SENT,
  transferConfirmedUnsent,
} from './payout-transfer-state';

function merchantTransferIdFor(withdrawalId: string): string {
  return `w${withdrawalId.replace(/-/g, '')}`;
}

function maskVpa(vpa: string): string {
  const at = vpa.indexOf('@');
  const local = at > 0 ? vpa.slice(0, at) : vpa;
  const domain = at > 0 ? vpa.slice(at) : '';
  const visible = local.slice(0, 1);
  return `${visible}***${domain}`;
}

function maskAccountNumber(accountNumber: string): string {
  const tail = accountNumber.slice(-4);
  return `XXXXXX${tail}`;
}

@Injectable()
export class WalletCodService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly repo: WalletCodRepository,
    private readonly idempotency: IdempotencyRepository,
    private readonly identities: IdentityRepository,
    private readonly walletNotifications: WalletNotificationDispatcher,
    @Inject(forwardRef(() => CashfreePaymentService))
    private readonly cashfree: CashfreePaymentService,
    private readonly config: ConfigService,
    @Inject(forwardRef(() => OrdersRepository))
    private readonly orders: OrdersRepository,
    private readonly logger: AppLogger,
  ) {}

  async getOwnWallet(auth: AuthContext) {
    this.assertRider(auth);
    return this.postgres.transaction(async (tx) => {
      const finance = await this.repo.lockAccounts(auth.profileId, tx);
      await this.repo.syncOperationalStatus(
        auth.profileId,
        finance.cod.cod_due,
        finance.threshold,
        tx,
      );
      return this.serializeWallet(auth.profileId, finance);
    });
  }

  async getOwnWalletLedger(auth: AuthContext) {
    this.assertRider(auth);
    return this.postgres.transaction(async (tx) => {
      const finance = await this.repo.lockAccounts(auth.profileId, tx);
      const entries = await this.repo.listWalletLedger(
        finance.wallet.wallet_account_id,
        tx,
      );
      return { entries: entries.map((row) => serializeWalletLedger(row)) };
    });
  }

  async getOwnCod(auth: AuthContext) {
    this.assertRider(auth);
    return this.postgres.transaction(async (tx) => {
      const finance = await this.repo.lockAccounts(auth.profileId, tx);
      const status = await this.repo.syncOperationalStatus(
        auth.profileId,
        finance.cod.cod_due,
        finance.threshold,
        tx,
      );
      return this.serializeCod(auth.profileId, finance, status, tx);
    });
  }

  async getOwnCodLedger(auth: AuthContext) {
    this.assertRider(auth);
    return this.postgres.transaction(async (tx) => {
      const finance = await this.repo.lockAccounts(auth.profileId, tx);
      const entries = await this.repo.listCodLedger(finance.cod.cod_account_id, tx);
      return { entries: entries.map((row) => serializeCodLedger(row)) };
    });
  }

  async getOwnEarnings(auth: AuthContext) {
    this.assertRider(auth);
    const earnings = await this.repo.listEarnings(auth.profileId);
    return { earnings: earnings.map((row) => serializeEarning(row)) };
  }

  async getAdminWallet(auth: AuthContext, riderProfileId: string) {
    await this.assertAdminFinance(auth);
    return this.postgres.transaction(async (tx) => {
      await this.requireRider(riderProfileId, tx);
      const finance = await this.repo.lockAccounts(riderProfileId, tx);
      return this.serializeWallet(riderProfileId, finance);
    });
  }

  async getAdminWalletLedger(auth: AuthContext, riderProfileId: string) {
    await this.assertAdminFinance(auth);
    return this.postgres.transaction(async (tx) => {
      await this.requireRider(riderProfileId, tx);
      const finance = await this.repo.lockAccounts(riderProfileId, tx);
      const entries = await this.repo.listWalletLedger(
        finance.wallet.wallet_account_id,
        tx,
      );
      return { entries: entries.map((row) => serializeWalletLedger(row)) };
    });
  }

  async getAdminCod(auth: AuthContext, riderProfileId: string) {
    await this.assertAdminFinance(auth);
    return this.postgres.transaction(async (tx) => {
      await this.requireRider(riderProfileId, tx);
      const finance = await this.repo.lockAccounts(riderProfileId, tx);
      const status = await this.repo.syncOperationalStatus(
        riderProfileId,
        finance.cod.cod_due,
        finance.threshold,
        tx,
      );
      return this.serializeCod(riderProfileId, finance, status, tx);
    });
  }

  async getAdminCodLedger(auth: AuthContext, riderProfileId: string) {
    await this.assertAdminFinance(auth);
    return this.postgres.transaction(async (tx) => {
      await this.requireRider(riderProfileId, tx);
      const finance = await this.repo.lockAccounts(riderProfileId, tx);
      const entries = await this.repo.listCodLedger(finance.cod.cod_account_id, tx);
      return { entries: entries.map((row) => serializeCodLedger(row)) };
    });
  }

  async getAdminEarnings(auth: AuthContext, riderProfileId: string) {
    await this.assertAdminFinance(auth);
    if (!(await this.repo.riderExists(riderProfileId))) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider was not found', 404);
    }
    const earnings = await this.repo.listEarnings(riderProfileId);
    return { earnings: earnings.map((row) => serializeEarning(row)) };
  }

  async applyVerifiedWalletTopUp(
    input: {
      paymentTransactionId: string;
      riderProfileId: string;
      amount: string;
    },
    db: Queryable,
  ) {
    const sourceTxnId = `wallet-topup:${input.paymentTransactionId}`;
    const existingWallet = await this.repo.findWalletLedgerByPaymentTransactionId(
      input.paymentTransactionId,
      db,
    );
    const finance = await this.repo.lockAccounts(input.riderProfileId, db);
    // All-COD top-ups create no wallet ledger row; COD source_txn_id is the
    // durable idempotency key for that case (cod_ledger_source_txn_unique).
    const existingCod = await this.repo.hasDigitalEarningSettlement(
      finance.cod.cod_account_id,
      sourceTxnId,
      db,
    );
    if (existingWallet || existingCod) {
      return {
        rider_profile_id: input.riderProfileId,
        available_balance: formatInr(finance.wallet.available_balance),
        cod_due: formatInr(finance.cod.cod_due),
        wallet_ledger_id: existingWallet?.wallet_ledger_id ?? null,
        idempotent_replay: true,
      };
    }
    const result = await this.applyInflow(db, {
      riderProfileId: input.riderProfileId,
      amount: input.amount,
      walletEntryType: 'RECHARGE',
      codSource: 'RECHARGE_SETTLEMENT',
      sourceTxnId,
      actorType: 'WEBHOOK',
      actorProfileId: null,
      allowWalletCredit: true,
      relatedPaymentTransactionId: input.paymentTransactionId,
      locked: finance,
    });
    return { ...result, idempotent_replay: false };
  }

  async saveOwnUpi(auth: AuthContext, vpaRaw: string) {
    this.assertRider(auth);
    const vpa = vpaRaw.trim();
    const masked = maskVpa(vpa);
    const stored = this.sealInstrument(vpa);
    const saved = await this.postgres.transaction((tx) =>
      this.repo.replaceCurrentUpi(auth.profileId, masked, stored, tx),
    );
    if (!saved) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider profile was not found', 404);
    }
    return {
      rider_upi_id: saved.rider_upi_id,
      vpa_masked: saved.vpa_masked,
      is_current: true,
    };
  }

  async clearOwnUpi(auth: AuthContext) {
    this.assertRider(auth);
    const cleared = await this.postgres.transaction((tx) =>
      this.repo.clearCurrentUpi(auth.profileId, tx),
    );
    if (!cleared) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider profile was not found', 404);
    }
    return { cleared: true };
  }

  async getOwnDestinations(auth: AuthContext) {
    this.assertRider(auth);
    const upi = await this.repo.findCurrentUpi(auth.profileId, this.postgres);
    const bank = await this.repo.findCurrentBankAccount(auth.profileId, this.postgres);
    return {
      upi: upi
        ? {
            available: true,
            vpa_masked: upi.vpa_masked,
            status: upi.cashfree_beneficiary_status ?? null,
          }
        : { available: false },
      bank: bank
        ? {
            available: true,
            account_masked: bank.account_masked,
            ifsc: bank.ifsc_or_bank,
            holder_name: bank.holder_name,
            status: bank.cashfree_beneficiary_status ?? null,
          }
        : { available: false },
    };
  }

  async saveOwnBank(
    auth: AuthContext,
    input: { holderName: string; accountNumber: string; ifsc: string },
  ) {
    this.assertRider(auth);
    const accountNumber = input.accountNumber.replace(/\s+/g, '');
    const ifsc = input.ifsc.trim().toUpperCase();
    const storedAccount = this.sealInstrument(accountNumber);
    const saved = await this.postgres.transaction((tx) =>
      this.repo.replaceCurrentBank(
        auth.profileId,
        {
          holderName: input.holderName.trim(),
          accountMasked: maskAccountNumber(accountNumber),
          accountNumber: storedAccount,
          ifsc,
        },
        tx,
      ),
    );
    if (!saved) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider profile was not found', 404);
    }
    return {
      bank_account_id: saved.bank_account_id,
      account_masked: saved.account_masked,
      is_current: true,
    };
  }

  async requestWithdraw(
    auth: AuthContext,
    amountRaw: string,
    payoutMethod: 'UPI' | 'BANK',
    idempotencyKey: string,
  ) {
    this.assertRider(auth);
    const amount = this.readPositive(amountRaw);
    return this.runIdempotent({
      auth,
      scope: 'wallet-withdraw',
      idempotencyKey,
      requestHash: hashRequest({ amount, payout_method: payoutMethod }),
      work: async (tx) => {
        const finance = await this.repo.lockAccounts(auth.profileId, tx);
        if (await this.repo.exceeds(amount, finance.wallet.available_balance, tx)) {
          throw new ApiError(
            ErrorCodes.WALLET_INSUFFICIENT,
            'Withdrawal exceeds available wallet balance',
            409,
          );
        }
        let riderUpiId: string | null = null;
        let bankAccountId: string | null = null;
        if (payoutMethod === 'UPI') {
          const upi = await this.repo.findCurrentUpi(auth.profileId, tx);
          if (!upi) {
            throw new ApiError(
              ErrorCodes.VALIDATION_ERROR,
              'Set a current UPI ID before requesting a UPI withdrawal',
              409,
            );
          }
          riderUpiId = upi.rider_upi_id;
          this.assertEncryptedInstrument(upi.vpa_encrypted_or_token);
          const driver = await this.identities.findRiderDriver(auth.profileId, tx);
          if (!cashfreeBeneficiaryName(driver?.name)) {
            throw new ApiError(
              ErrorCodes.VALIDATION_ERROR,
              'A rider name with at least two letters is required before a UPI withdrawal',
              409,
            );
          }
        } else {
          const bank = await this.repo.findCurrentBankAccount(auth.profileId, tx);
          if (!bank) {
            throw new ApiError(
              ErrorCodes.VALIDATION_ERROR,
              'Set a current bank account before requesting a bank withdrawal',
              409,
            );
          }
          bankAccountId = bank.bank_account_id;
          this.assertEncryptedInstrument(bank.account_encrypted_or_token);
          if (!cashfreeBeneficiaryName(bank.holder_name)) {
            throw new ApiError(
              ErrorCodes.VALIDATION_ERROR,
              'The bank account holder name must contain at least two letters before a bank withdrawal',
              409,
            );
          }
        }
        const decreased = await this.repo.debitWallet(
          finance.wallet.wallet_account_id,
          amount,
          tx,
        );
        if (decreased === null) {
          throw new ApiError(
            ErrorCodes.WALLET_INSUFFICIENT,
            'Withdrawal exceeds available wallet balance',
            409,
          );
        }
        const ledger = await this.repo.insertWalletLedger(
          {
            walletAccountId: finance.wallet.wallet_account_id,
            direction: 'DEBIT',
            amount,
            entryType: 'PAYOUT',
            actorType: 'RIDER',
            actorProfileId: auth.profileId,
          },
          tx,
        );
        const withdrawal = await this.repo.insertWithdrawal(
          {
            riderProfileId: auth.profileId,
            amount,
            payoutMethod,
            riderUpiId,
            bankAccountId,
            walletLedgerId: ledger.wallet_ledger_id,
          },
          tx,
        );
        await this.walletNotifications.onWithdrawalRequested(
          {
            riderProfileId: auth.profileId,
            withdrawalId: withdrawal.withdrawal_id,
            amount,
          },
          tx,
        );
        return {
          withdrawal_id: withdrawal.withdrawal_id,
          status: withdrawal.status,
          amount: formatInr(amount),
          available_balance: decreased,
          wallet_ledger_id: ledger.wallet_ledger_id,
        };
      },
    });
  }

  async listAdminWithdrawals(auth: AuthContext) {
    await this.assertAdminFinance(auth);
    const rows = await this.repo.listWithdrawals();
    return {
      withdrawals: rows.map((row) => this.serializeWithdrawal(row)),
    };
  }

  async getAdminWithdrawal(auth: AuthContext, withdrawalId: string) {
    await this.assertAdminFinance(auth);
    const listed = await this.repo.listWithdrawals();
    const summary = listed.find((row) => row.withdrawal_id === withdrawalId);
    if (!summary) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Withdrawal was not found', 404);
    }
    let destinationMasked: string | null = null;
    if (summary.payout_method === 'UPI' && summary.rider_upi_id) {
      const upi = await this.repo.findUpiById(summary.rider_upi_id, this.postgres);
      destinationMasked = upi?.vpa_masked ?? null;
    } else if (summary.payout_method === 'BANK' && summary.bank_account_id) {
      const bank = await this.repo.findBankById(
        summary.bank_account_id,
        this.postgres,
      );
      destinationMasked = bank
        ? `${bank.account_masked}${bank.ifsc_or_bank ? ` / ${bank.ifsc_or_bank}` : ''}`
        : null;
    }
    return {
      ...this.serializeWithdrawal(summary),
      destination_masked: destinationMasked,
    };
  }

  async getAdminWalletTopUps(auth: AuthContext, riderProfileId: string) {
    await this.assertAdminFinance(auth);
    await this.postgres.transaction(async (tx) => {
      await this.requireRider(riderProfileId, tx);
    });
    const rows = await this.repo.listWalletTopUps(riderProfileId);
    return {
      topups: rows.map((row) => ({
        payment_transaction_id: row.payment_transaction_id,
        rider_profile_id: riderProfileId,
        amount: formatInr(row.amount),
        status: row.transaction_status,
        provider_txn_id: row.provider_txn_id,
        gateway_order_id: row.gateway_order_id,
        created_at: row.created_at.toISOString(),
      })),
    };
  }

  async rejectWithdrawal(
    auth: AuthContext,
    withdrawalId: string,
    reason?: string,
  ) {
    await this.assertAdminFinance(auth);
    return this.postgres.transaction(async (tx) => {
      const row = await this.repo.lockWithdrawal(withdrawalId, tx);
      if (!row) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Withdrawal was not found', 404);
      }
      const unsentProcessing = transferConfirmedUnsent(
        row.provider_status,
        row.provider_transfer_id,
      );
      if (
        row.status !== 'REQUESTED' &&
        row.status !== 'PENDING' &&
        !(row.status === 'PROCESSING' && unsentProcessing)
      ) {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          row.status === 'PROCESSING'
            ? 'Only an unsent withdrawal can be rejected. The Cashfree transfer outcome is still unknown'
            : 'Only requested withdrawals can be rejected',
          409,
        );
      }
      const restored = await this.refundWithdrawalOnce(
        {
          withdrawalId,
          riderProfileId: row.rider_profile_id,
          amount: row.amount,
          actorType: 'ADMIN',
          actorProfileId: auth.profileId,
          notifyType: 'WITHDRAWAL_REJECTED',
        },
        tx,
      );
      await this.repo.updateWithdrawalStatus(
        {
          withdrawalId,
          status: 'REJECTED',
          decidedByAdminProfileId: auth.profileId,
          failureReason: reason?.trim() || null,
          processed: true,
          refundWalletLedgerId: restored.wallet_ledger_id,
        },
        tx,
      );
      return {
        withdrawal_id: withdrawalId,
        status: 'REJECTED',
        available_balance: restored.available_balance,
      };
    });
  }

  /**
   * Moves REQUESTED → PROCESSING, then initiates Cashfree payout.
   * On clear provider rejection: FAILED + single refund.
   * On timeout/unknown after accept ambiguity: remains PROCESSING for reconcile.
   */
  async markWithdrawalProcessing(auth: AuthContext, withdrawalId: string) {
    await this.assertAdminFinance(auth);
    const payment = this.config.getOrThrow<AppConfig['payment']>('payment');
    if (payment.provider !== 'cashfree') {
      throw new ApiError(
        ErrorCodes.PAYMENT_PROVIDER_UNAVAILABLE,
        'Cashfree payouts are not configured',
        503,
      );
    }

    const prepared = await this.postgres.transaction(async (tx) => {
      const row = await this.repo.lockWithdrawal(withdrawalId, tx);
      if (!row) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Withdrawal was not found', 404);
      }
      if (row.status === 'PROCESSING' && row.merchant_transfer_id) {
        return {
          alreadyProcessing: true as const,
          withdrawalId,
          merchantTransferId: row.merchant_transfer_id,
          amount: row.amount,
          payoutMethod: row.payout_method as 'UPI' | 'BANK',
          riderProfileId: row.rider_profile_id,
          riderUpiId: row.rider_upi_id,
          bankAccountId: row.bank_account_id,
        };
      }
      if (row.status !== 'REQUESTED') {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Only requested withdrawals can move to processing',
          409,
        );
      }
      const merchantTransferId =
        row.merchant_transfer_id ?? merchantTransferIdFor(withdrawalId);
      await this.repo.updateWithdrawalStatus(
        {
          withdrawalId,
          status: 'PROCESSING',
          decidedByAdminProfileId: auth.profileId,
          merchantTransferId,
          providerStatus: TRANSFER_NOT_SENT,
        },
        tx,
      );
      await this.walletNotifications.onWithdrawalEvent(
        {
          riderProfileId: row.rider_profile_id,
          withdrawalId,
          amount: formatInr(row.amount),
          type: 'WITHDRAWAL_PROCESSING',
        },
        tx,
      );
      return {
        alreadyProcessing: false as const,
        withdrawalId,
        merchantTransferId,
        amount: row.amount,
        payoutMethod: row.payout_method as 'UPI' | 'BANK',
        riderProfileId: row.rider_profile_id,
        riderUpiId: row.rider_upi_id,
        bankAccountId: row.bank_account_id,
      };
    });

    if (prepared.alreadyProcessing) {
      await this.reconcileWithdrawal(prepared.withdrawalId);
      return { withdrawal_id: withdrawalId, status: 'PROCESSING' };
    }

    return this.continuePayout(prepared);
  }

  /**
   * Registers the destination's beneficiary when needed, then sends one transfer.
   * Unknown registration or transfer results stay PROCESSING and are not refunded.
   */
  private async continuePayout(prepared: {
    withdrawalId: string;
    merchantTransferId: string;
    amount: string;
    payoutMethod: 'UPI' | 'BANK';
    riderProfileId: string;
    riderUpiId: string | null;
    bankAccountId: string | null;
  }): Promise<{ withdrawal_id: string; status: string }> {
    const withdrawalId = prepared.withdrawalId;
    const gate = await this.ensurePayoutBeneficiary(prepared);
    if (gate.state === 'wait') {
      return { withdrawal_id: withdrawalId, status: 'PROCESSING' };
    }
    if (gate.state === 'unavailable') {
      if (gate.reason === 'instrument_unreadable') {
        await this.reportUnsentBlocker(
          withdrawalId,
          'Payout destination cannot be read with the configured key',
        );
        return { withdrawal_id: withdrawalId, status: 'PROCESSING' };
      }
      const failed = await this.failConfirmedUnsentWithdrawal(
        withdrawalId,
        gate.reason === 'beneficiary_name_missing'
          ? 'Beneficiary name is missing'
          : 'Payout destination is missing',
      );
      return {
        withdrawal_id: withdrawalId,
        status: failed ? 'FAILED' : 'PROCESSING',
      };
    }
    if (gate.state === 'rejected') {
      const failed = await this.failConfirmedUnsentWithdrawal(
        withdrawalId,
        'Cashfree rejected the beneficiary',
      );
      return {
        withdrawal_id: withdrawalId,
        status: failed ? 'FAILED' : 'PROCESSING',
      };
    }
    const claimed = await this.postgres.transaction((tx) =>
      this.repo.claimPayoutTransferDispatch(withdrawalId, tx),
    );
    if (!claimed) {
      return { withdrawal_id: withdrawalId, status: 'PROCESSING' };
    }
    try {
      const transfer = await this.cashfree.initiatePayoutTransfer({
        merchantTransferId: prepared.merchantTransferId,
        amount: prepared.amount,
        payoutMethod: prepared.payoutMethod,
        beneficiaryId: gate.beneficiaryId,
        vpa: gate.vpa,
        bankAccountNumber: gate.bankAccountNumber,
        bankIfsc: gate.bankIfsc,
      });
      if (transfer.outcome === 'rejected') {
        await this.applyAuthoritativePayoutOutcome({
          withdrawalId,
          outcome: 'failed',
          providerTransferId: transfer.providerTransferId,
          providerStatus: transfer.providerStatus,
          failureReason: transfer.failureReason,
        });
        return { withdrawal_id: withdrawalId, status: 'FAILED' };
      }
      await this.postgres.transaction(async (tx) => {
        const row = await this.repo.lockWithdrawal(withdrawalId, tx);
        if (!row || row.status !== 'PROCESSING') {
          return;
        }
        await this.repo.updateWithdrawalStatus(
          {
            withdrawalId,
            status: 'PROCESSING',
            providerTransferId: transfer.providerTransferId,
            providerStatus: transfer.providerStatus,
            touchReconciled: true,
          },
          tx,
        );
      });
      const status = (transfer.providerStatus ?? '').toUpperCase();
      if (status === 'SUCCESS' || status === 'COMPLETED') {
        await this.applyAuthoritativePayoutOutcome({
          withdrawalId,
          outcome: 'success',
          providerTransferId: transfer.providerTransferId,
          providerStatus: transfer.providerStatus,
          failureReason: null,
        });
        return { withdrawal_id: withdrawalId, status: 'SUCCESSFUL' };
      }
      if (
        status === 'FAILED' ||
        status === 'REJECTED' ||
        status === 'FAILED_AT_BANK'
      ) {
        await this.applyAuthoritativePayoutOutcome({
          withdrawalId,
          outcome: 'failed',
          providerTransferId: transfer.providerTransferId,
          providerStatus: transfer.providerStatus,
          failureReason: transfer.failureReason,
        });
        return { withdrawal_id: withdrawalId, status: 'FAILED' };
      }
      return { withdrawal_id: withdrawalId, status: 'PROCESSING' };
    } catch (err) {
      if (err instanceof PayoutTransferNotDispatchedError) {
        await this.postgres.transaction((tx) =>
          this.repo.releasePayoutTransferDispatch(withdrawalId, tx),
        );
        return { withdrawal_id: withdrawalId, status: 'PROCESSING' };
      }
      // The request may have reached Cashfree. Keep the claim and the debit.
      this.logger.warn('cashfree_payout_initiate_uncertain', {
        withdrawal_id: withdrawalId,
        merchant_transfer_id: prepared.merchantTransferId,
        error: err instanceof Error ? err.message : 'unknown',
      });
      return { withdrawal_id: withdrawalId, status: 'PROCESSING' };
    }
  }

  async applyAuthoritativePayoutOutcome(input: {
    withdrawalId: string;
    outcome: 'success' | 'failed' | 'reversed' | 'pending' | 'unknown';
    providerTransferId: string | null;
    providerStatus: string | null;
    failureReason: string | null;
  }): Promise<{ status: string; result: string }> {
    return this.postgres.transaction(async (tx) => {
      const row = await this.repo.lockWithdrawal(input.withdrawalId, tx);
      if (!row) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Withdrawal was not found', 404);
      }
      if (input.outcome === 'pending' || input.outcome === 'unknown') {
        await this.repo.updateWithdrawalStatus(
          {
            withdrawalId: input.withdrawalId,
            status: row.status,
            providerTransferId: input.providerTransferId,
            providerStatus: input.providerStatus,
            failureReason: input.failureReason,
            touchReconciled: true,
          },
          tx,
        );
        return {
          status: row.status,
          result: input.outcome === 'unknown' ? 'requires_review' : 'pending',
        };
      }
      if (input.outcome === 'success') {
        if (row.status === 'SUCCESSFUL') {
          return { status: 'SUCCESSFUL', result: 'duplicate' };
        }
        if (row.status !== 'PROCESSING') {
          return { status: row.status, result: 'ignored' };
        }
        await this.repo.updateWithdrawalStatus(
          {
            withdrawalId: input.withdrawalId,
            status: 'SUCCESSFUL',
            providerTransferId: input.providerTransferId,
            providerStatus: input.providerStatus ?? 'SUCCESS',
            processed: true,
            touchReconciled: true,
          },
          tx,
        );
        await this.walletNotifications.onWithdrawalEvent(
          {
            riderProfileId: row.rider_profile_id,
            withdrawalId: input.withdrawalId,
            amount: formatInr(row.amount),
            type: 'WITHDRAWAL_SUCCESSFUL',
            reference: input.providerTransferId,
          },
          tx,
        );
        return { status: 'SUCCESSFUL', result: 'applied' };
      }
      if (input.outcome === 'failed') {
        if (row.status === 'FAILED' || row.status === 'REJECTED') {
          return { status: row.status, result: 'duplicate' };
        }
        if (row.status !== 'PROCESSING') {
          return { status: row.status, result: 'ignored' };
        }
        const restored = await this.refundWithdrawalOnce(
          {
            withdrawalId: input.withdrawalId,
            riderProfileId: row.rider_profile_id,
            amount: row.amount,
            actorType: 'SYSTEM',
            actorProfileId: null,
            notifyType: 'WITHDRAWAL_FAILED',
          },
          tx,
        );
        await this.repo.updateWithdrawalStatus(
          {
            withdrawalId: input.withdrawalId,
            status: 'FAILED',
            providerTransferId: input.providerTransferId,
            providerStatus: input.providerStatus ?? 'FAILED',
            failureReason: input.failureReason,
            processed: true,
            refundWalletLedgerId: restored.wallet_ledger_id,
            touchReconciled: true,
          },
          tx,
        );
        return { status: 'FAILED', result: 'applied' };
      }
      // reversed after success (or while processing)
      if (row.status === 'CANCELLED' && row.refund_wallet_ledger_id) {
        return { status: 'CANCELLED', result: 'duplicate' };
      }
      if (row.status !== 'SUCCESSFUL' && row.status !== 'PROCESSING') {
        return { status: row.status, result: 'ignored' };
      }
      const restored = await this.refundWithdrawalOnce(
        {
          withdrawalId: input.withdrawalId,
          riderProfileId: row.rider_profile_id,
          amount: row.amount,
          actorType: 'SYSTEM',
          actorProfileId: null,
          notifyType: 'WITHDRAWAL_REFUNDED',
        },
        tx,
      );
      await this.repo.updateWithdrawalStatus(
        {
          withdrawalId: input.withdrawalId,
          status: 'CANCELLED',
          providerTransferId: input.providerTransferId,
          providerStatus: input.providerStatus ?? 'REVERSED',
          failureReason: input.failureReason ?? 'Provider reversed the transfer',
          processed: true,
          refundWalletLedgerId: restored.wallet_ledger_id,
          touchReconciled: true,
        },
        tx,
      );
      return { status: 'CANCELLED', result: 'applied' };
    });
  }

  async applyPayoutWebhookByMerchantTransferId(input: {
    merchantTransferId: string;
    providerTransferId: string | null;
    providerStatus: string;
    failureReason: string | null;
  }): Promise<{ status: string; result: string }> {
    const found = await this.repo.findWithdrawalByMerchantTransferId(
      input.merchantTransferId,
    );
    if (!found) {
      return { status: 'UNKNOWN', result: 'ignored' };
    }
    const mapped = this.mapProviderStatus(input.providerStatus);
    return this.applyAuthoritativePayoutOutcome({
      withdrawalId: found.withdrawal_id,
      outcome: mapped,
      providerTransferId: input.providerTransferId,
      providerStatus: input.providerStatus,
      failureReason: input.failureReason,
    });
  }

  async reconcileWithdrawal(withdrawalId: string): Promise<{
    status: string;
    result: string;
  }> {
    const payment = this.config.getOrThrow<AppConfig['payment']>('payment');
    if (payment.provider !== 'cashfree') {
      return { status: 'PROCESSING', result: 'requires_review' };
    }
    const locked = await this.postgres.transaction(async (tx) => {
      return this.repo.lockWithdrawal(withdrawalId, tx);
    });
    if (!locked) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Withdrawal was not found', 404);
    }
    if (locked.status !== 'PROCESSING' || !locked.merchant_transfer_id) {
      return { status: locked.status, result: 'ignored' };
    }
    try {
      const snapshot = await this.cashfree.retrievePayoutTransfer(
        locked.merchant_transfer_id,
      );
      if (snapshot.outcome === 'not_found') {
        if (
          !transferConfirmedUnsent(
            locked.provider_status,
            locked.provider_transfer_id,
          )
        ) {
          return { status: 'PROCESSING', result: 'requires_review' };
        }
        const continued = await this.continuePayout({
          withdrawalId,
          merchantTransferId: locked.merchant_transfer_id,
          amount: locked.amount,
          payoutMethod: locked.payout_method as 'UPI' | 'BANK',
          riderProfileId: locked.rider_profile_id,
          riderUpiId: locked.rider_upi_id,
          bankAccountId: locked.bank_account_id,
        });
        return {
          status: continued.status,
          result: continued.status === 'FAILED' ? 'applied' : 'requires_review',
        };
      }
      return this.applyAuthoritativePayoutOutcome({
        withdrawalId,
        outcome: snapshot.outcome,
        providerTransferId: snapshot.providerTransferId,
        providerStatus: snapshot.providerStatus,
        failureReason: snapshot.failureReason,
      });
    } catch (err) {
      this.logger.warn('cashfree_payout_reconcile_uncertain', {
        withdrawal_id: withdrawalId,
        error: err instanceof Error ? err.message : 'unknown',
      });
      await this.postgres.transaction(async (tx) => {
        await this.repo.updateWithdrawalStatus(
          {
            withdrawalId,
            status: 'PROCESSING',
            touchReconciled: true,
          },
          tx,
        );
      });
      return { status: 'PROCESSING', result: 'requires_review' };
    }
  }

  async reconcileDueWithdrawals(): Promise<{
    claimed: number;
    applied: number;
    requires_review: number;
  }> {
    const reconcile =
      this.config.getOrThrow<AppConfig['payment']>('payment').payoutReconcile;
    const due = await this.repo.listProcessingForReconcile(
      reconcile.minAgeSeconds,
      reconcile.batchSize,
    );
    let applied = 0;
    let requiresReview = 0;
    for (const row of due) {
      const result = await this.reconcileWithdrawal(row.withdrawal_id);
      if (result.result === 'applied') {
        applied += 1;
      } else if (result.result === 'requires_review' || result.result === 'pending') {
        requiresReview += 1;
      }
    }
    return { claimed: due.length, applied, requires_review: requiresReview };
  }

  private mapProviderStatus(
    providerStatus: string,
  ): 'success' | 'failed' | 'reversed' | 'pending' | 'unknown' {
    const status = providerStatus.toUpperCase();
    if (status === 'SUCCESS' || status === 'COMPLETED') {
      return 'success';
    }
    if (status === 'FAILED' || status === 'REJECTED' || status === 'FAILED_AT_BANK') {
      return 'failed';
    }
    if (status === 'REVERSED') {
      return 'reversed';
    }
    if (status === 'PENDING' || status === 'RECEIVED' || status === 'APPROVAL_PENDING') {
      return 'pending';
    }
    return 'unknown';
  }

  private async refundWithdrawalOnce(
    input: {
      withdrawalId: string;
      riderProfileId: string;
      amount: string;
      actorType: WalletActorType;
      actorProfileId: string | null;
      notifyType: 'WITHDRAWAL_FAILED' | 'WITHDRAWAL_REJECTED' | 'WITHDRAWAL_REFUNDED';
    },
    db: Queryable,
  ): Promise<{ available_balance: string; wallet_ledger_id: string }> {
    const existing = await this.repo.lockWithdrawal(input.withdrawalId, db);
    if (existing?.refund_wallet_ledger_id) {
      const finance = await this.repo.lockAccounts(input.riderProfileId, db);
      return {
        available_balance: formatInr(finance.wallet.available_balance),
        wallet_ledger_id: existing.refund_wallet_ledger_id,
      };
    }
    const finance = await this.repo.lockAccounts(input.riderProfileId, db);
    const restored = await this.repo.creditWallet(
      finance.wallet.wallet_account_id,
      input.amount,
      db,
    );
    const ledger = await this.repo.insertWalletLedger(
      {
        walletAccountId: finance.wallet.wallet_account_id,
        direction: 'CREDIT',
        amount: input.amount,
        entryType: 'ADJUSTMENT',
        actorType: input.actorType,
        actorProfileId: input.actorProfileId,
      },
      db,
    );
    await this.repo.updateWithdrawalStatus(
      {
        withdrawalId: input.withdrawalId,
        status: existing?.status ?? 'PROCESSING',
        refundWalletLedgerId: ledger.wallet_ledger_id,
      },
      db,
    );
    await this.walletNotifications.onWithdrawalEvent(
      {
        riderProfileId: input.riderProfileId,
        withdrawalId: input.withdrawalId,
        amount: formatInr(input.amount),
        type: input.notifyType,
      },
      db,
    );
    return {
      available_balance: restored,
      wallet_ledger_id: ledger.wallet_ledger_id,
    };
  }

  private serializeWithdrawal(row: {
    withdrawal_id: string;
    rider_profile_id: string;
    amount: string;
    status: string;
    payout_method: string;
    rider_upi_id?: string | null;
    bank_account_id?: string | null;
    merchant_transfer_id?: string | null;
    provider_transfer_id?: string | null;
    provider_status?: string | null;
    failure_reason?: string | null;
    requested_at?: Date;
    processed_at?: Date | null;
    updated_at?: Date;
  }) {
    return {
      withdrawal_id: row.withdrawal_id,
      rider_profile_id: row.rider_profile_id,
      amount: formatInr(row.amount),
      status: row.status,
      payout_method: row.payout_method,
      rider_upi_id: row.rider_upi_id ?? null,
      bank_account_id: row.bank_account_id ?? null,
      merchant_transfer_id: row.merchant_transfer_id ?? null,
      provider_transfer_id: row.provider_transfer_id ?? null,
      provider_status: row.provider_status ?? null,
      failure_reason: row.failure_reason ?? null,
      requested_at: row.requested_at?.toISOString?.() ?? null,
      processed_at: row.processed_at ? row.processed_at.toISOString() : null,
      updated_at: row.updated_at?.toISOString?.() ?? null,
    };
  }

  async settle(
    auth: AuthContext,
    amountRaw: string,
    idempotencyKey: string,
  ) {
    this.assertRider(auth);
    const amount = this.readPositive(amountRaw);
    return this.runIdempotent({
      auth,
      scope: 'cod-settlement',
      idempotencyKey,
      requestHash: hashRequest({ amount }),
      work: async (tx) => {
        const finance = await this.repo.lockAccounts(auth.profileId, tx);
        if (await this.repo.exceeds(amount, finance.cod.cod_due, tx)) {
          throw new ApiError(
            ErrorCodes.COD_SETTLEMENT_EXCEEDS_DUE,
            'Settlement cannot exceed COD Due',
            409,
          );
        }
        return this.applyInflow(tx, {
          riderProfileId: auth.profileId,
          amount,
          walletEntryType: 'RECHARGE',
          codSource: 'RECHARGE_SETTLEMENT',
          sourceTxnId: `settle:${auth.identityId}:${idempotencyKey}`,
          actorType: 'RIDER',
          actorProfileId: auth.profileId,
          allowWalletCredit: false,
          locked: finance,
        });
      },
    });
  }

  /**
   * Posts COD / digital-earning consequences for a frozen order.
   * Cash-trip rider share is physical cash and is NOT posted to wallet.
   * A fully digital trip credits the frozen snapshot rider_amount only after
   * the booking charge is PAID by a verified Cashfree webhook. A missing
   * payment plan is neither cash nor a paid digital trip.
   */
  async syncOrderFinance(order: OrderRow, db: Queryable): Promise<void> {
    if (!order.rider_profile_id) {
      return;
    }
    const lockedOrder = await this.orders.lockById(order.order_id, db);
    if (!lockedOrder?.rider_profile_id) {
      return;
    }
    const snapshot = await this.repo.findOriginalSnapshot(order.order_id, db);
    if (!snapshot) {
      return;
    }
    const finance = await this.repo.lockAccounts(lockedOrder.rider_profile_id, db);
    const cash = await this.repo.cashCollected(order.order_id, db);
    const riderAmount = formatInr(snapshot.rider_amount);
    const plan = await this.repo.findOrderPaymentPlan(order.order_id, db);

    // COD company share and digital rider earnings require the locked order to
    // be DELIVERED. Operational-status sync/notifications still run below.
    if (lockedOrder.canonical_status === 'DELIVERED') {
      if (await this.repo.isPositive(cash, db)) {
        const targetDue = await this.repo.companyDueFromCash(cash, riderAmount, db);
        const posted = await this.repo.postedCashCompanyShare(
          finance.cod.cod_account_id,
          order.order_id,
          db,
        );
        if (await this.repo.exceeds(targetDue, posted, db)) {
          const delta = await this.repo.subtract(targetDue, posted, db);
          await this.postCodIncrease(finance, {
            amount: delta,
            source: 'CASH_COMPANY_SHARE',
            relatedOrderId: order.order_id,
            sourceTxnId: `cash-cod:${order.order_id}:${posted}:${delta}`,
          }, db);
        }
      } else if (await this.digitalEarningReady(plan, riderAmount, order.order_id, db)) {
        const alreadyPosted =
          (await this.repo.hasWalletEarningForOrder(
            finance.wallet.wallet_account_id,
            order.order_id,
            db,
          )) ||
          (await this.repo.hasDigitalEarningSettlement(
            finance.cod.cod_account_id,
            `earning:${snapshot.finance_snapshot_id}`,
            db,
          ));
        if (!alreadyPosted) {
          try {
            await this.applyInflow(db, {
              riderProfileId: lockedOrder.rider_profile_id,
              amount: riderAmount,
              walletEntryType: 'EARNING',
              codSource: 'DIGITAL_EARNING_SETTLEMENT',
              sourceTxnId: `earning:${snapshot.finance_snapshot_id}`,
              actorType: 'SYSTEM',
              actorProfileId: null,
              allowWalletCredit: true,
              relatedOrderId: order.order_id,
              locked: finance,
            });
          } catch (err) {
            if (!isUniqueViolation(err, 'cod_ledger_source_txn_unique')) {
              throw err;
            }
          }
        }
      } else if (
        this.planIsFullyDigital(plan) &&
        (await this.repo.isPositive(riderAmount, db))
      ) {
        this.logger.info('digital_earning_deferred', {
          order_id: order.order_id,
          reason: 'online_booking_not_verified_paid',
        });
      } else if (!plan && (await this.repo.isPositive(riderAmount, db))) {
        this.logger.info('digital_earning_deferred', {
          order_id: order.order_id,
          reason: 'payment_plan_missing',
        });
      }
    }

    const latest = await this.repo.lockAccounts(order.rider_profile_id, db);
    const previous = await this.repo.operationalStatus(order.rider_profile_id, db);
    const current = await this.repo.syncOperationalStatus(
      order.rider_profile_id,
      latest.cod.cod_due,
      latest.threshold,
      db,
    );
    await this.walletNotifications.onOperationalStatusChange(
      {
        riderProfileId: order.rider_profile_id,
        previous,
        current,
        sourceTxnId: `order-finance:${order.order_id}`,
      },
      db,
    );
  }

  private planIsFullyDigital(
    plan: { planned_online: string; planned_cash: string } | null,
  ): boolean {
    if (!plan) {
      return false;
    }
    return (
      formatInr(plan.planned_cash) === '0.00' &&
      formatInr(plan.planned_online) !== '0.00'
    );
  }

  /**
   * Digital earning waits until the verified paid booking total equals the
   * planned online total. PENDING, FAILED, missing, and partial charges defer.
   */
  private async digitalEarningReady(
    plan: { planned_online: string; planned_cash: string } | null,
    riderAmount: string,
    orderId: string,
    db: Queryable,
  ): Promise<boolean> {
    if (!this.planIsFullyDigital(plan) || !plan) {
      return false;
    }
    if (!(await this.repo.isPositive(riderAmount, db))) {
      return false;
    }
    const verified = await this.repo.verifiedOnlineBookingPaid(orderId, db);
    return formatInr(verified) === formatInr(plan.planned_online);
  }

  async assertNotSuspended(riderProfileId: string, db: Queryable): Promise<void> {
    const finance = await this.repo.lockAccounts(riderProfileId, db);
    const status = await this.repo.syncOperationalStatus(
      riderProfileId,
      finance.cod.cod_due,
      finance.threshold,
      db,
    );
    if (
      status === 'SUSPENDED_FOR_COD' ||
      (await this.repo.isAtLeast(finance.cod.cod_due, finance.threshold, db))
    ) {
      throw new ApiError(
        ErrorCodes.RIDER_NOT_ELIGIBLE,
        'Rider is suspended for COD and cannot accept offers',
        409,
      );
    }
  }

  private async applyInflow(
    db: Queryable,
    input: {
      riderProfileId: string;
      amount: string;
      walletEntryType: 'RECHARGE' | 'EARNING';
      codSource: 'RECHARGE_SETTLEMENT' | 'DIGITAL_EARNING_SETTLEMENT';
      sourceTxnId: string;
      actorType: WalletActorType;
      actorProfileId: string | null;
      allowWalletCredit: boolean;
      relatedOrderId?: string | null;
      relatedPaymentTransactionId?: string | null;
      locked?: LockedRiderFinance;
    },
  ) {
    const finance =
      input.locked ?? (await this.repo.lockAccounts(input.riderProfileId, db));
    const split = await this.repo.splitInflow(
      input.amount,
      finance.cod.cod_due,
      db,
    );
    if (!input.allowWalletCredit && (await this.repo.isPositive(split.remainder, db))) {
      throw new ApiError(
        ErrorCodes.COD_SETTLEMENT_EXCEEDS_DUE,
        'Settlement cannot exceed COD Due',
        409,
      );
    }

    let walletBalance = formatInr(finance.wallet.available_balance);
    let codDue = formatInr(finance.cod.cod_due);
    let walletLedgerId: string | null = null;
    let codLedgerId: string | null = null;

    const settleNeeded = await this.repo.isPositive(split.settle, db);
    const creditNeeded =
      input.allowWalletCredit && (await this.repo.isPositive(split.remainder, db));

    if (settleNeeded && creditNeeded) {
      const ids = await this.repo.newIds(db);
      walletLedgerId = ids.walletLedgerId;
      codLedgerId = ids.codLedgerId;
      const decreased = await this.repo.decreaseCod(
        finance.cod.cod_account_id,
        split.settle,
        db,
      );
      if (decreased === null) {
        throw new ApiError(
          ErrorCodes.COD_SETTLEMENT_EXCEEDS_DUE,
          'Settlement cannot exceed COD Due',
          409,
        );
      }
      codDue = decreased;
      walletBalance = await this.repo.creditWallet(
        finance.wallet.wallet_account_id,
        split.remainder,
        db,
      );
      await this.repo.insertCodLedger(
        {
          codLedgerId,
          codAccountId: finance.cod.cod_account_id,
          direction: 'DECREASE',
          amount: split.settle,
          source: input.codSource,
          relatedOrderId: input.relatedOrderId ?? null,
          relatedWalletLedgerId: walletLedgerId,
          sourceTxnId: input.sourceTxnId,
        },
        db,
      );
      await this.repo.insertWalletLedger(
        {
          walletLedgerId,
          walletAccountId: finance.wallet.wallet_account_id,
          direction: 'CREDIT',
          amount: split.remainder,
          entryType: input.walletEntryType,
          relatedOrderId: input.relatedOrderId ?? null,
          relatedPaymentTransactionId: input.relatedPaymentTransactionId ?? null,
          relatedCodLedgerId: codLedgerId,
          actorType: input.actorType,
          actorProfileId: input.actorProfileId,
        },
        db,
      );
    } else if (settleNeeded) {
      const decreased = await this.repo.decreaseCod(
        finance.cod.cod_account_id,
        split.settle,
        db,
      );
      if (decreased === null) {
        throw new ApiError(
          ErrorCodes.COD_SETTLEMENT_EXCEEDS_DUE,
          'Settlement cannot exceed COD Due',
          409,
        );
      }
      codDue = decreased;
      const row = await this.repo.insertCodLedger(
        {
          codAccountId: finance.cod.cod_account_id,
          direction: 'DECREASE',
          amount: split.settle,
          source: input.codSource,
          relatedOrderId: input.relatedOrderId ?? null,
          sourceTxnId: input.sourceTxnId,
        },
        db,
      );
      codLedgerId = row.cod_ledger_id;
    } else if (creditNeeded) {
      walletBalance = await this.repo.creditWallet(
        finance.wallet.wallet_account_id,
        split.remainder,
        db,
      );
      const row = await this.repo.insertWalletLedger(
        {
          walletAccountId: finance.wallet.wallet_account_id,
          direction: 'CREDIT',
          amount: split.remainder,
          entryType: input.walletEntryType,
          relatedOrderId: input.relatedOrderId ?? null,
          relatedPaymentTransactionId: input.relatedPaymentTransactionId ?? null,
          actorType: input.actorType,
          actorProfileId: input.actorProfileId,
        },
        db,
      );
      walletLedgerId = row.wallet_ledger_id;
    }

    const previous = await this.repo.operationalStatus(input.riderProfileId, db);
    const status = await this.repo.syncOperationalStatus(
      input.riderProfileId,
      codDue,
      finance.threshold,
      db,
    );
    const ledgerNet = await this.repo.walletLedgerNet(
      finance.wallet.wallet_account_id,
      db,
    );
    const codNet = await this.repo.codLedgerNet(finance.cod.cod_account_id, db);
    if (ledgerNet !== walletBalance || codNet !== codDue) {
      throw new ApiError(
        ErrorCodes.INTERNAL_ERROR,
        'Wallet/COD materialized balance does not match the ledger',
        500,
      );
    }

    if (
      input.walletEntryType === 'RECHARGE' &&
      input.codSource === 'RECHARGE_SETTLEMENT'
    ) {
      if (input.allowWalletCredit) {
        await this.walletNotifications.onRechargeCompleted(
          {
            riderProfileId: input.riderProfileId,
            sourceTxnId: input.sourceTxnId,
            amount: input.amount,
          },
          db,
        );
      }
      if (settleNeeded) {
        await this.walletNotifications.onCodSettlementCompleted(
          {
            riderProfileId: input.riderProfileId,
            sourceTxnId: input.sourceTxnId,
            amount: split.settle,
          },
          db,
        );
      }
    }
    await this.walletNotifications.onOperationalStatusChange(
      {
        riderProfileId: input.riderProfileId,
        previous,
        current: status,
        sourceTxnId: input.sourceTxnId,
      },
      db,
    );

    return {
      rider_profile_id: input.riderProfileId,
      available_balance: walletBalance,
      cod_due: codDue,
      settled_against_cod: split.settle,
      wallet_credited: creditNeeded ? split.remainder : formatInr('0'),
      suspended: status === 'SUSPENDED_FOR_COD',
      suspend_threshold: formatInr(finance.threshold),
      wallet_ledger_id: walletLedgerId,
      cod_ledger_id: codLedgerId,
    };
  }

  private async postCodIncrease(
    finance: LockedRiderFinance,
    input: {
      amount: string;
      source: 'CASH_COMPANY_SHARE';
      relatedOrderId: string;
      sourceTxnId: string;
    },
    db: Queryable,
  ): Promise<void> {
    if (!(await this.repo.isPositive(input.amount, db))) {
      return;
    }
    await this.repo.increaseCod(finance.cod.cod_account_id, input.amount, db);
    await this.repo.insertCodLedger(
      {
        codAccountId: finance.cod.cod_account_id,
        direction: 'INCREASE',
        amount: input.amount,
        source: input.source,
        relatedOrderId: input.relatedOrderId,
        sourceTxnId: input.sourceTxnId,
      },
      db,
    );
  }

  private async runIdempotent<T>(input: {
    auth: AuthContext;
    scope: IdempotencyScope;
    idempotencyKey: string;
    requestHash: string;
    work: (tx: Queryable) => Promise<T>;
  }): Promise<T> {
    const scopedKey = `${input.auth.identityId}:${input.idempotencyKey}`;
    const existing = await this.idempotency.find(input.scope, scopedKey);
    if (existing) {
      return this.replayOrConflict(
        existing.request_hash,
        input.requestHash,
        existing.result_payload as T,
      );
    }
    try {
      return await this.postgres.transaction(async (tx) => {
        const replay = await this.idempotency.find(input.scope, scopedKey, tx);
        if (replay) {
          return this.replayOrConflict(
            replay.request_hash,
            input.requestHash,
            replay.result_payload as T,
          );
        }
        const payload = await input.work(tx);
        await this.idempotency.insert(
          {
            scope: input.scope,
            key: scopedKey,
            actorIdentityId: input.auth.identityId,
            requestHash: input.requestHash,
            resultEntityId:
              (payload as { wallet_ledger_id?: string | null; cod_ledger_id?: string | null })
                .wallet_ledger_id ??
              (payload as { cod_ledger_id?: string | null }).cod_ledger_id ??
              input.auth.profileId,
            resultPayload: payload,
          },
          tx,
        );
        return payload;
      });
    } catch (err) {
      if (isUniqueViolation(err, 'idempotency_scope_key_unique')) {
        const raced = await this.idempotency.find(input.scope, scopedKey);
        if (!raced) {
          throw err;
        }
        return this.replayOrConflict(
          raced.request_hash,
          input.requestHash,
          raced.result_payload as T,
        );
      }
      if (isUniqueViolation(err, 'cod_ledger_source_txn_unique')) {
        const raced = await this.idempotency.find(input.scope, scopedKey);
        if (raced) {
          return this.replayOrConflict(
            raced.request_hash,
            input.requestHash,
            raced.result_payload as T,
          );
        }
      }
      if (isCheckViolation(err)) {
        throw new ApiError(
          ErrorCodes.WALLET_INSUFFICIENT,
          'Wallet or COD Due cannot become negative',
          409,
        );
      }
      throw err;
    }
  }

  private serializeWallet(riderProfileId: string, finance: LockedRiderFinance) {
    return {
      rider_profile_id: riderProfileId,
      wallet_account_id: finance.wallet.wallet_account_id,
      available_balance: formatInr(finance.wallet.available_balance),
    };
  }

  private async serializeCod(
    riderProfileId: string,
    finance: LockedRiderFinance,
    status: 'CLEAR' | 'SUSPENDED_FOR_COD',
    db: Queryable,
  ) {
    const suspended = await this.repo.isAtLeast(
      finance.cod.cod_due,
      finance.threshold,
      db,
    );
    return {
      rider_profile_id: riderProfileId,
      cod_account_id: finance.cod.cod_account_id,
      cod_due: formatInr(finance.cod.cod_due),
      suspend_threshold: formatInr(finance.threshold),
      suspended,
      cod_operational_status: status,
    };
  }

  private async requireRider(riderProfileId: string, db: Queryable): Promise<void> {
    if (!(await this.repo.riderExists(riderProfileId, db))) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider was not found', 404);
    }
  }

  private async assertAdminFinance(auth: AuthContext): Promise<void> {
    if (auth.role !== 'ADMIN') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin role required', 403);
    }
    const profile = await this.identities.findAdminProfile(auth.identityId);
    if (!profile || profile.admin_profile_id !== auth.profileId) {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin profile required', 403);
    }
    const allowed =
      profile.role === 'SUPER_ADMIN' ||
      profile.role === 'FINANCE' ||
      profile.finance_access === true;
    if (!allowed) {
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        'Finance access is required to view rider wallet and COD',
        403,
      );
    }
  }

  private sealInstrument(plaintext: string): string {
    const key = this.payoutKey();
    if (!key) {
      throw new ApiError(
        ErrorCodes.PAYMENT_PROVIDER_UNAVAILABLE,
        'Payout instrument encryption is not configured',
        503,
      );
    }
    return encryptPayoutInstrument(plaintext, key);
  }

  private assertEncryptedInstrument(stored: string): void {
    const key = this.payoutKey();
    if (!key) {
      throw new ApiError(
        ErrorCodes.PAYMENT_PROVIDER_UNAVAILABLE,
        'Payout instrument encryption is not configured',
        503,
      );
    }
    if (!stored.startsWith('enc1:')) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Save the payout destination again before requesting a withdrawal',
        409,
      );
    }
    try {
      decryptPayoutInstrument(stored, key);
    } catch {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Save the payout destination again before requesting a withdrawal',
        409,
      );
    }
  }

  /**
   * Refunds once only while this process has recorded that no transfer request
   * was sent. A claimed or legacy row is left PROCESSING.
   */
  private async failConfirmedUnsentWithdrawal(
    withdrawalId: string,
    failureReason: string,
  ): Promise<boolean> {
    return this.postgres.transaction(async (tx) => {
      const row = await this.repo.lockWithdrawal(withdrawalId, tx);
      if (!row || row.status !== 'PROCESSING') {
        return false;
      }
      if (!transferConfirmedUnsent(row.provider_status, row.provider_transfer_id)) {
        return false;
      }
      const restored = await this.refundWithdrawalOnce(
        {
          withdrawalId,
          riderProfileId: row.rider_profile_id,
          amount: row.amount,
          actorType: 'SYSTEM',
          actorProfileId: null,
          notifyType: 'WITHDRAWAL_FAILED',
        },
        tx,
      );
      await this.repo.updateWithdrawalStatus(
        {
          withdrawalId,
          status: 'FAILED',
          providerStatus: 'FAILED',
          failureReason,
          processed: true,
          refundWalletLedgerId: restored.wallet_ledger_id,
          touchReconciled: true,
        },
        tx,
      );
      return true;
    });
  }

  private async reportUnsentBlocker(
    withdrawalId: string,
    failureReason: string,
  ): Promise<void> {
    await this.postgres.transaction(async (tx) => {
      const row = await this.repo.lockWithdrawal(withdrawalId, tx);
      if (
        !row ||
        row.status !== 'PROCESSING' ||
        !transferConfirmedUnsent(row.provider_status, row.provider_transfer_id)
      ) {
        return;
      }
      await this.repo.updateWithdrawalStatus(
        {
          withdrawalId,
          status: 'PROCESSING',
          failureReason,
          touchReconciled: true,
        },
        tx,
      );
    });
  }

  private openInstrument(stored: string): string | null {
    try {
      return decryptPayoutInstrument(stored, this.payoutKey());
    } catch {
      this.logger.warn('payout_instrument_unreadable', {});
      return null;
    }
  }

  private payoutKey(): Buffer | null {
    const raw = this.config.getOrThrow<AppConfig['payment']>('payment').payoutInstrumentKey;
    if (!raw) {
      return null;
    }
    const key = Buffer.from(raw, 'base64');
    return key.length === 32 ? key : null;
  }

  private async ensurePayoutBeneficiary(prepared: {
    payoutMethod: 'UPI' | 'BANK';
    riderProfileId: string;
    riderUpiId: string | null;
    bankAccountId: string | null;
  }): Promise<
    | {
        state: 'ready';
        beneficiaryId: string;
        vpa: string | null;
        bankAccountNumber: string | null;
        bankIfsc: string | null;
      }
    | { state: 'wait' }
    | { state: 'rejected' }
    | {
        state: 'unavailable';
        reason:
          | 'destination_missing'
          | 'instrument_unreadable'
          | 'beneficiary_name_missing';
      }
  > {
    const loaded = await this.postgres.transaction(async (tx) => {
      if (prepared.payoutMethod === 'UPI') {
        if (!prepared.riderUpiId) {
          return null;
        }
        const upi = await this.repo.findUpiById(prepared.riderUpiId, tx);
        if (!upi?.vpa_encrypted_or_token) {
          return null;
        }
        const expectedId = payoutBeneficiaryId('UPI', upi.rider_upi_id);
        const registered =
          upi.cashfree_beneficiary_status === 'REGISTERED' &&
          upi.cashfree_beneficiary_id === expectedId;
        const driver = registered
          ? null
          : await this.identities.findRiderDriver(prepared.riderProfileId, tx);
        return {
          kind: 'UPI' as const,
          destinationId: upi.rider_upi_id,
          storedInstrument: upi.vpa_encrypted_or_token,
          ifsc: null as string | null,
          name: cashfreeBeneficiaryName(driver?.name),
          registered,
          beneficiaryId: upi.cashfree_beneficiary_id,
          status: upi.cashfree_beneficiary_status,
        };
      }
      if (!prepared.bankAccountId) {
        return null;
      }
      const bank = await this.repo.findBankById(prepared.bankAccountId, tx);
      if (!bank?.account_encrypted_or_token || !bank.ifsc_or_bank) {
        return null;
      }
      const expectedId = payoutBeneficiaryId('BANK', bank.bank_account_id);
      const registered =
        bank.cashfree_beneficiary_status === 'REGISTERED' &&
        bank.cashfree_beneficiary_id === expectedId;
      return {
        kind: 'BANK' as const,
        destinationId: bank.bank_account_id,
        storedInstrument: bank.account_encrypted_or_token,
        ifsc: bank.ifsc_or_bank,
        name: cashfreeBeneficiaryName(bank.holder_name),
        registered,
        beneficiaryId: bank.cashfree_beneficiary_id,
        status: bank.cashfree_beneficiary_status,
      };
    });
    if (!loaded) {
      return { state: 'unavailable', reason: 'destination_missing' };
    }
    const instrument = this.openInstrument(loaded.storedInstrument);
    if (!instrument) {
      return { state: 'unavailable', reason: 'instrument_unreadable' };
    }
    const vpa = loaded.kind === 'UPI' ? instrument : null;
    const bankAccountNumber = loaded.kind === 'BANK' ? instrument : null;
    if (
      loaded.registered &&
      loaded.beneficiaryId &&
      loaded.beneficiaryId === payoutBeneficiaryId(loaded.kind, loaded.destinationId)
    ) {
      return {
        state: 'ready',
        beneficiaryId: loaded.beneficiaryId,
        vpa,
        bankAccountNumber,
        bankIfsc: loaded.ifsc,
      };
    }
    if (!loaded.name) {
      return { state: 'unavailable', reason: 'beneficiary_name_missing' };
    }
    const beneficiaryName = loaded.name;
    const beneficiaryId = payoutBeneficiaryId(loaded.kind, loaded.destinationId);
    await this.postgres.transaction(async (tx) => {
      if (loaded.kind === 'UPI') {
        await this.repo.saveUpiBeneficiary(loaded.destinationId, beneficiaryId, 'UNKNOWN', tx);
      } else {
        await this.repo.saveBankBeneficiary(loaded.destinationId, beneficiaryId, 'UNKNOWN', tx);
      }
    });
    const existing = await this.cashfree.getPayoutBeneficiary(beneficiaryId);
    if (existing.outcome === 'unknown') {
      return { state: 'wait' };
    }
    if (existing.outcome === 'registered' && existing.beneficiaryId === beneficiaryId) {
      await this.markBeneficiaryRegistered(loaded.kind, loaded.destinationId, beneficiaryId);
      return {
        state: 'ready',
        beneficiaryId,
        vpa,
        bankAccountNumber,
        bankIfsc: loaded.ifsc,
      };
    }
    if (existing.outcome !== 'missing') {
      return { state: 'wait' };
    }
    const created = await this.cashfree.registerPayoutBeneficiary({
      beneficiaryId,
      beneficiaryName,
      payoutMethod: loaded.kind,
      vpa,
      bankAccountNumber,
      bankIfsc: loaded.ifsc,
    });
    if (created.outcome === 'unknown') {
      return { state: 'wait' };
    }
    if (created.outcome === 'rejected') {
      return { state: 'rejected' };
    }
    const confirmed = await this.cashfree.getPayoutBeneficiary(beneficiaryId);
    if (confirmed.outcome === 'registered' && confirmed.beneficiaryId === beneficiaryId) {
      await this.markBeneficiaryRegistered(loaded.kind, loaded.destinationId, beneficiaryId);
      return {
        state: 'ready',
        beneficiaryId,
        vpa,
        bankAccountNumber,
        bankIfsc: loaded.ifsc,
      };
    }
    return { state: 'wait' };
  }

  private async markBeneficiaryRegistered(
    kind: 'UPI' | 'BANK',
    destinationId: string,
    beneficiaryId: string,
  ): Promise<void> {
    await this.postgres.transaction(async (tx) => {
      if (kind === 'UPI') {
        await this.repo.saveUpiBeneficiary(destinationId, beneficiaryId, 'REGISTERED', tx);
      } else {
        await this.repo.saveBankBeneficiary(destinationId, beneficiaryId, 'REGISTERED', tx);
      }
    });
  }

  private assertRider(auth: AuthContext): void {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider role required', 403);
    }
  }

  private readPositive(raw: string): string {
    try {
      return assertPositiveInr(raw);
    } catch {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Amount must be a positive INR decimal',
        400,
      );
    }
  }

  private replayOrConflict<T>(
    storedHash: string,
    requestHash: string,
    payload: T,
  ): T {
    if (storedHash !== requestHash) {
      throw new ApiError(
        ErrorCodes.IDEMPOTENCY_CONFLICT,
        'Idempotency-Key was reused with a different request',
        409,
      );
    }
    return payload;
  }
}
