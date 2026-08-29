import { Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository } from '../auth/identity/identity.repository';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { isCheckViolation, isUniqueViolation } from '../common/pg-error';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { assertPositiveInr, formatInr } from '../fare/money';
import {
  hashRequest,
  IdempotencyRepository,
  IdempotencyScope,
} from '../orders/idempotency.repository';
import { OrderRow } from '../orders/orders.repository';
import { WalletNotificationDispatcher } from '../notifications/wallet-notification.dispatcher';
import {
  LockedRiderFinance,
  serializeCodLedger,
  serializeEarning,
  serializeWalletLedger,
  WalletActorType,
  WalletCodRepository,
} from './wallet-cod.repository';

@Injectable()
export class WalletCodService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly repo: WalletCodRepository,
    private readonly idempotency: IdempotencyRepository,
    private readonly identities: IdentityRepository,
    private readonly walletNotifications: WalletNotificationDispatcher,
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

  async recharge(
    auth: AuthContext,
    amountRaw: string,
    idempotencyKey: string,
  ) {
    this.assertRider(auth);
    const amount = this.readPositive(amountRaw);
    return this.runIdempotent({
      auth,
      scope: 'recharge',
      idempotencyKey,
      requestHash: hashRequest({ amount }),
      work: (tx) =>
        this.applyInflow(tx, {
          riderProfileId: auth.profileId,
          amount,
          walletEntryType: 'RECHARGE',
          codSource: 'RECHARGE_SETTLEMENT',
          sourceTxnId: `recharge:${auth.identityId}:${idempotencyKey}`,
          actorType: 'RIDER',
          actorProfileId: auth.profileId,
          allowWalletCredit: true,
        }),
    });
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
   * Digital earning uses the frozen snapshot rider_amount (never live 85/15).
   */
  async syncOrderFinance(order: OrderRow, db: Queryable): Promise<void> {
    if (!order.rider_profile_id) {
      return;
    }
    const snapshot = await this.repo.findOriginalSnapshot(order.order_id, db);
    if (!snapshot) {
      return;
    }
    const finance = await this.repo.lockAccounts(order.rider_profile_id, db);
    const cash = await this.repo.cashCollected(order.order_id, db);
    const plannedCash = await this.repo.plannedCash(order.order_id, db);
    const riderAmount = formatInr(snapshot.rider_amount);

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
    } else if (
      (await this.repo.isPositive(riderAmount, db)) &&
      !(await this.repo.isPositive(plannedCash, db)) &&
      !(await this.repo.hasWalletEarningForOrder(
        finance.wallet.wallet_account_id,
        order.order_id,
        db,
      )) &&
      !(await this.repo.hasDigitalEarningSettlement(
        finance.cod.cod_account_id,
        `earning:${snapshot.finance_snapshot_id}`,
        db,
      ))
    ) {
      try {
        await this.applyInflow(db, {
          riderProfileId: order.rider_profile_id,
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
