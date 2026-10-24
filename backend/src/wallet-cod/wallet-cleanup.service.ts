import { Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { AuditService } from '../audit/audit.service';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { isCheckViolation, isDeadlock, isUniqueViolation } from '../common/pg-error';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { formatInr } from '../fare/money';
import { WalletCleanupDto, WalletCleanupPreviewDto } from './dto/wallet-cleanup.dto';
import {
  assessCodCleanup,
  assessCustomerWalletCleanup,
  assessRiderWalletCleanup,
  centsToInr,
  CleanupAssessment,
} from './wallet-cleanup.policy';
import { WalletCodRepository } from './wallet-cod.repository';

@Injectable()
export class WalletCleanupService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly repo: WalletCodRepository,
    private readonly audit: AuditService,
  ) {}

  async preview(auth: AuthContext, body: WalletCleanupPreviewDto) {
    this.assertAdmin(auth);
    return this.postgres.transaction(async (tx) => this.inspect(body, tx));
  }

  async apply(auth: AuthContext, body: WalletCleanupDto) {
    this.assertAdmin(auth);
    const reason = body.reason.trim();
    if (reason.length < 8) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Give a reason of at least 8 characters.',
        422,
      );
    }
    if (body.confirm !== true) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Confirm the cleanup after reviewing the balance impact.',
        422,
      );
    }
    try {
      return await this.postgres.transaction(async (tx) => {
        const inspection = await this.inspect(body, tx);
        if (inspection.already_reversed) {
          return { ...inspection, result: 'already_reversed' };
        }
        if (!inspection.allowed) {
          throw new ApiError(
            ErrorCodes.WALLET_CLEANUP_REJECTED,
            inspection.reasons[0] ?? 'This wallet entry cannot be cleaned up.',
            409,
            { reasons: inspection.reasons, ledger_id: body.ledger_id },
          );
        }
        if (body.ledger_kind === 'RIDER_WALLET') {
          await this.reverseRiderWallet(auth, body.ledger_id, reason, tx);
        } else if (body.ledger_kind === 'RIDER_COD') {
          await this.reverseCod(auth, body.ledger_id, reason, tx);
        } else {
          await this.reverseCustomerWallet(auth, body.ledger_id, reason, tx);
        }
        const after = await this.inspect(body, tx);
        await this.audit.recordRequired(
          {
            auth,
            action: 'WALLET_ENTRY_REVERSED',
            entityType: body.ledger_kind,
            entityId: body.ledger_id,
            category: 'FINANCIAL',
            reason,
            oldValue: {
              balance_before: inspection.balance_before,
              amount: inspection.amount,
              direction: inspection.direction,
            },
            newValue: {
              balance_after: after.balance_before,
              reversal_id: after.reversal_id,
            },
          },
          tx,
        );
        return { ...after, result: 'reversed' };
      });
    } catch (err) {
      if (
        isUniqueViolation(err, 'wallet_ledger_reversal_once') ||
        isUniqueViolation(err, 'cod_ledger_reversal_once') ||
        isUniqueViolation(err, 'customer_wallet_ledger_reversal_once') ||
        isUniqueViolation(err, 'cod_ledger_source_txn_unique')
      ) {
        const existing = await this.preview(auth, body);
        if (existing.already_reversed) {
          return { ...existing, result: 'already_reversed' };
        }
        throw new ApiError(
          ErrorCodes.WALLET_CLEANUP_REJECTED,
          'This cleanup conflicted with another ledger row. Nothing was changed. Try again.',
          409,
        );
      }
      if (isCheckViolation(err)) {
        throw new ApiError(
          ErrorCodes.WALLET_CLEANUP_REJECTED,
          'The reversal would make a wallet or COD balance negative, so it was not applied.',
          409,
        );
      }
      if (isDeadlock(err)) {
        throw new ApiError(
          ErrorCodes.WALLET_CLEANUP_REJECTED,
          'This cleanup conflicted with another wallet update. Nothing was changed. Try again.',
          409,
        );
      }
      throw err;
    }
  }

  private async reverseRiderWallet(
    auth: AuthContext,
    ledgerId: string,
    reason: string,
    tx: Queryable,
  ) {
    const row = await this.repo.lockWalletLedger(ledgerId, tx);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Wallet entry was not found', 404);
    }
    const opposite = row.direction === 'CREDIT' ? 'DEBIT' : 'CREDIT';
    await this.repo.insertWalletReversal(
      {
        walletAccountId: row.wallet_account_id,
        direction: opposite,
        amount: formatInr(row.amount),
        reversesWalletLedgerId: row.wallet_ledger_id,
        reason,
        actorProfileId: auth.profileId,
        relatedOrderId: row.related_order_id,
        relatedCodLedgerId: null,
      },
      tx,
    );
    if (row.related_cod_ledger_id) {
      const cod = await this.repo.lockCodLedger(row.related_cod_ledger_id, tx);
      if (cod && !(await this.repo.findCodReversal(cod.cod_ledger_id, tx))) {
        await this.repo.insertCodReversal(
          {
            codAccountId: cod.cod_account_id,
            direction: cod.direction === 'INCREASE' ? 'DECREASE' : 'INCREASE',
            amount: formatInr(cod.amount),
            reversesCodLedgerId: cod.cod_ledger_id,
            reason,
            relatedOrderId: cod.related_order_id,
          },
          tx,
        );
        await this.repo.recomputeCodDue(cod.cod_account_id, tx);
      }
    }
    await this.repo.recomputeWalletBalance(row.wallet_account_id, tx);
  }

  private async reverseCod(
    auth: AuthContext,
    ledgerId: string,
    reason: string,
    tx: Queryable,
  ) {
    const row = await this.repo.lockCodLedger(ledgerId, tx);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'COD entry was not found', 404);
    }
    await this.repo.insertCodReversal(
      {
        codAccountId: row.cod_account_id,
        direction: row.direction === 'INCREASE' ? 'DECREASE' : 'INCREASE',
        amount: formatInr(row.amount),
        reversesCodLedgerId: row.cod_ledger_id,
        reason,
        relatedOrderId: row.related_order_id,
        relatedWalletLedgerId: null,
      },
      tx,
    );
    if (row.related_wallet_ledger_id) {
      const wallet = await this.repo.lockWalletLedger(row.related_wallet_ledger_id, tx);
      if (wallet && !(await this.repo.findWalletReversal(wallet.wallet_ledger_id, tx))) {
        await this.repo.insertWalletReversal(
          {
            walletAccountId: wallet.wallet_account_id,
            direction: wallet.direction === 'CREDIT' ? 'DEBIT' : 'CREDIT',
            amount: formatInr(wallet.amount),
            reversesWalletLedgerId: wallet.wallet_ledger_id,
            reason,
            actorProfileId: auth.profileId,
            relatedOrderId: wallet.related_order_id,
          },
          tx,
        );
        await this.repo.recomputeWalletBalance(wallet.wallet_account_id, tx);
      }
    }
    await this.repo.recomputeCodDue(row.cod_account_id, tx);
  }

  private async reverseCustomerWallet(
    auth: AuthContext,
    ledgerId: string,
    reason: string,
    tx: Queryable,
  ) {
    const row = await this.repo.lockCustomerWalletLedger(ledgerId, tx);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Customer wallet entry was not found', 404);
    }
    await this.repo.insertCustomerWalletReversal(
      {
        customerWalletId: row.customer_wallet_id,
        direction: row.direction === 'CREDIT' ? 'DEBIT' : 'CREDIT',
        amount: formatInr(row.amount),
        reversesLedgerId: row.customer_wallet_ledger_id,
        reason,
        actorProfileId: auth.profileId,
        relatedOrderId: row.related_order_id,
      },
      tx,
    );
    await this.repo.recomputeCustomerWalletBalance(row.customer_wallet_id, tx);
  }

  private async inspect(body: WalletCleanupPreviewDto, tx: Queryable) {
    if (body.ledger_kind === 'RIDER_WALLET') {
      const row = await this.repo.lockWalletLedger(body.ledger_id, tx);
      if (!row) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Wallet entry was not found', 404);
      }
      const reversal = await this.repo.findWalletReversal(row.wallet_ledger_id, tx);
      const pairedCod = row.related_cod_ledger_id
        ? await this.repo.lockCodLedger(row.related_cod_ledger_id, tx)
        : null;
      const assessment = assessRiderWalletCleanup({
        entryType: row.entry_type,
        direction: row.direction,
        amount: row.amount,
        balance: row.ledger_balance,
        relatedOrderId: row.related_order_id,
        relatedPaymentTransactionId: row.related_payment_transaction_id,
        relatedCodLedgerId: row.related_cod_ledger_id,
        pairedCodSource: pairedCod?.source ?? null,
        pairedCod: pairedCod
          ? {
              direction: pairedCod.direction,
              amount: pairedCod.amount,
              due: pairedCod.ledger_due,
            }
          : null,
        alreadyReversed: reversal != null,
      });
      return this.payload(body, row.direction, row.amount, row.entry_type, row.ledger_balance, assessment, reversal?.wallet_ledger_id ?? null);
    }
    if (body.ledger_kind === 'RIDER_COD') {
      const row = await this.repo.lockCodLedger(body.ledger_id, tx);
      if (!row) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'COD entry was not found', 404);
      }
      const reversal = await this.repo.findCodReversal(row.cod_ledger_id, tx);
      const pairedWallet = row.related_wallet_ledger_id
        ? await this.repo.lockWalletLedger(row.related_wallet_ledger_id, tx)
        : null;
      const assessment = assessCodCleanup({
        source: row.source,
        direction: row.direction,
        amount: row.amount,
        codDue: row.ledger_due,
        relatedOrderId: row.related_order_id,
        relatedWalletEntryType: pairedWallet?.entry_type ?? null,
        pairedWallet: pairedWallet
          ? {
              direction: pairedWallet.direction,
              amount: pairedWallet.amount,
              balance: pairedWallet.ledger_balance,
            }
          : null,
        alreadyReversed: reversal != null,
      });
      return this.payload(body, row.direction, row.amount, row.source, row.ledger_due, assessment, reversal?.cod_ledger_id ?? null);
    }
    const row = await this.repo.lockCustomerWalletLedger(body.ledger_id, tx);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Customer wallet entry was not found', 404);
    }
    const reversal = await this.repo.findCustomerWalletReversal(row.customer_wallet_ledger_id, tx);
    const assessment = assessCustomerWalletCleanup({
      entryType: row.entry_type,
      direction: row.direction,
      amount: row.amount,
      balance: row.ledger_balance,
      relatedOrderId: row.related_order_id,
      alreadyReversed: reversal != null,
    });
    return this.payload(
      body,
      row.direction,
      row.amount,
      row.entry_type,
      row.ledger_balance,
      assessment,
      reversal?.customer_wallet_ledger_id ?? null,
    );
  }

  private payload(
    body: WalletCleanupPreviewDto,
    direction: string,
    amount: string,
    entryType: string,
    balance: string,
    assessment: CleanupAssessment,
    reversalId: string | null,
  ) {
    return {
      ledger_kind: body.ledger_kind,
      ledger_id: body.ledger_id,
      entry_type: entryType,
      direction,
      amount: formatInr(amount),
      balance_before: formatInr(balance),
      balance_delta: centsToInr(assessment.balance_delta_cents),
      projected_balance: assessment.projected_balance,
      allowed: assessment.allowed && reversalId == null,
      already_reversed: reversalId != null,
      reversal_id: reversalId,
      reasons: reversalId
        ? ['This entry already has a reversal.']
        : assessment.reasons,
      preserves_original: true,
    };
  }

  private assertAdmin(auth: AuthContext): void {
    if (auth.role !== 'ADMIN') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin role required', 403);
    }
  }
}
