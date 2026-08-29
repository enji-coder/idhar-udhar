import { Injectable } from '@nestjs/common';
import { formatInr } from '../fare/money';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';

export const LOCKED_COD_SUSPEND_THRESHOLD = '100.00';

export type WalletAccountRow = {
  wallet_account_id: string;
  rider_profile_id: string;
  available_balance: string;
};

export type CodAccountRow = {
  cod_account_id: string;
  rider_profile_id: string;
  cod_due: string;
};

export type LockedRiderFinance = {
  wallet: WalletAccountRow;
  cod: CodAccountRow;
  threshold: string;
};

export type WalletLedgerRow = {
  wallet_ledger_id: string;
  wallet_account_id: string;
  direction: 'CREDIT' | 'DEBIT';
  amount: string;
  entry_type: string;
  related_order_id: string | null;
  related_payment_transaction_id: string | null;
  related_cod_ledger_id: string | null;
  actor_type: string;
  actor_profile_id: string | null;
  created_at: Date;
};

export type CodLedgerRow = {
  cod_ledger_id: string;
  cod_account_id: string;
  direction: 'INCREASE' | 'DECREASE';
  amount: string;
  source: string;
  related_order_id: string | null;
  related_wallet_ledger_id: string | null;
  source_txn_id: string | null;
  created_at: Date;
};

export type RiderEarningRow = {
  finance_snapshot_id: string;
  order_id: string;
  display_id: string;
  snapshot_kind: string;
  trip_fare: string;
  rider_amount: string;
  company_commission_amount: string;
  operational_cost_amount: string;
  profit_amount: string;
  rider_percentage: string;
  company_commission_percentage: string;
  frozen_at: Date;
};

export type WalletActorType = 'CUSTOMER' | 'RIDER' | 'ADMIN' | 'WEBHOOK' | 'SYSTEM';

export type WalletEntryType =
  | 'EARNING'
  | 'COD_SETTLEMENT'
  | 'RECHARGE'
  | 'PAYOUT'
  | 'ADJUSTMENT'
  | 'CANCELLATION_SHARE'
  | 'RESEND_EARNING';

export type CodSource =
  | 'CASH_COMPANY_SHARE'
  | 'RECHARGE_SETTLEMENT'
  | 'DIGITAL_EARNING_SETTLEMENT'
  | 'CANCELLATION_SHARE_SETTLEMENT'
  | 'ADMIN_ADJUSTMENT';

const WALLET_LEDGER_COLUMNS = `
  wallet_ledger_id,
  wallet_account_id,
  direction,
  amount::text AS amount,
  entry_type,
  related_order_id,
  related_payment_transaction_id,
  related_cod_ledger_id,
  actor_type,
  actor_profile_id,
  created_at
`;

const COD_LEDGER_COLUMNS = `
  cod_ledger_id,
  cod_account_id,
  direction,
  amount::text AS amount,
  source,
  related_order_id,
  related_wallet_ledger_id,
  source_txn_id,
  created_at
`;

@Injectable()
export class WalletCodRepository {
  constructor(private readonly postgres: PostgresService) {}

  async lockAccounts(
    riderProfileId: string,
    db: Queryable,
  ): Promise<LockedRiderFinance> {
    await db.query(
      `
      INSERT INTO rider_wallet_accounts (rider_profile_id)
      VALUES ($1)
      ON CONFLICT (rider_profile_id) DO NOTHING
      `,
      [riderProfileId],
    );
    await db.query(
      `
      INSERT INTO rider_cod_accounts (rider_profile_id)
      VALUES ($1)
      ON CONFLICT (rider_profile_id) DO NOTHING
      `,
      [riderProfileId],
    );
    await db.query(
      `SELECT rider_profile_id FROM rider_profiles WHERE rider_profile_id = $1 FOR UPDATE`,
      [riderProfileId],
    );
    const wallet = await db.query<WalletAccountRow>(
      `
      SELECT
        wallet_account_id,
        rider_profile_id,
        available_balance::text AS available_balance
      FROM rider_wallet_accounts
      WHERE rider_profile_id = $1
      FOR UPDATE
      `,
      [riderProfileId],
    );
    const cod = await db.query<CodAccountRow>(
      `
      SELECT
        cod_account_id,
        rider_profile_id,
        cod_due::text AS cod_due
      FROM rider_cod_accounts
      WHERE rider_profile_id = $1
      FOR UPDATE
      `,
      [riderProfileId],
    );
    if (!wallet.rows[0] || !cod.rows[0]) {
      throw new Error('Rider wallet/COD accounts were not created');
    }
    return {
      wallet: wallet.rows[0],
      cod: cod.rows[0],
      threshold: await this.findActiveThreshold(db),
    };
  }

  async findAccounts(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<LockedRiderFinance | null> {
    const wallet = await db.query<WalletAccountRow>(
      `
      SELECT
        wallet_account_id,
        rider_profile_id,
        available_balance::text AS available_balance
      FROM rider_wallet_accounts
      WHERE rider_profile_id = $1
      `,
      [riderProfileId],
    );
    const cod = await db.query<CodAccountRow>(
      `
      SELECT
        cod_account_id,
        rider_profile_id,
        cod_due::text AS cod_due
      FROM rider_cod_accounts
      WHERE rider_profile_id = $1
      `,
      [riderProfileId],
    );
    if (!wallet.rows[0] && !cod.rows[0]) {
      return null;
    }
    return {
      wallet: wallet.rows[0] ?? {
        wallet_account_id: '',
        rider_profile_id: riderProfileId,
        available_balance: '0.00',
      },
      cod: cod.rows[0] ?? {
        cod_account_id: '',
        rider_profile_id: riderProfileId,
        cod_due: '0.00',
      },
      threshold: await this.findActiveThreshold(db),
    };
  }

  async riderExists(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<boolean> {
    const result = await db.query<{ ok: boolean }>(
      `SELECT EXISTS(SELECT 1 FROM rider_profiles WHERE rider_profile_id = $1) AS ok`,
      [riderProfileId],
    );
    return result.rows[0]?.ok === true;
  }

  async findActiveThreshold(db: Queryable = this.postgres): Promise<string> {
    const result = await db.query<{ suspend_threshold: string }>(
      `
      SELECT suspend_threshold::text AS suspend_threshold
      FROM cod_policy_versions
      WHERE status = 'ACTIVE'
      `,
    );
    if (!result.rows[0]) {
      return LOCKED_COD_SUSPEND_THRESHOLD;
    }
    return formatInr(result.rows[0].suspend_threshold);
  }

  async isAtLeast(
    left: string,
    right: string,
    db: Queryable,
  ): Promise<boolean> {
    const result = await db.query<{ ok: boolean }>(
      `SELECT $1::numeric(12,2) >= $2::numeric(12,2) AS ok`,
      [left, right],
    );
    return result.rows[0].ok;
  }

  async isPositive(amount: string, db: Queryable): Promise<boolean> {
    const result = await db.query<{ ok: boolean }>(
      `SELECT $1::numeric(12,2) > 0 AS ok`,
      [amount],
    );
    return result.rows[0].ok;
  }

  async exceeds(left: string, right: string, db: Queryable): Promise<boolean> {
    const result = await db.query<{ ok: boolean }>(
      `SELECT $1::numeric(12,2) > $2::numeric(12,2) AS ok`,
      [left, right],
    );
    return result.rows[0].ok;
  }

  async splitInflow(
    amount: string,
    codDue: string,
    db: Queryable,
  ): Promise<{ settle: string; remainder: string }> {
    const result = await db.query<{ settle: string; remainder: string }>(
      `
      SELECT
        LEAST($1::numeric(12,2), $2::numeric(12,2))::text AS settle,
        ($1::numeric(12,2) - LEAST($1::numeric(12,2), $2::numeric(12,2)))::text AS remainder
      `,
      [amount, codDue],
    );
    return {
      settle: formatInr(result.rows[0].settle),
      remainder: formatInr(result.rows[0].remainder),
    };
  }

  async companyDueFromCash(
    cashCollected: string,
    riderEarning: string,
    db: Queryable,
  ): Promise<string> {
    const result = await db.query<{ due: string }>(
      `
      SELECT GREATEST(
        0::numeric(12,2),
        $1::numeric(12,2) - $2::numeric(12,2)
      )::text AS due
      `,
      [cashCollected, riderEarning],
    );
    return formatInr(result.rows[0].due);
  }

  async subtract(left: string, right: string, db: Queryable): Promise<string> {
    const result = await db.query<{ value: string }>(
      `SELECT ($1::numeric(12,2) - $2::numeric(12,2))::text AS value`,
      [left, right],
    );
    return formatInr(result.rows[0].value);
  }

  async newIds(
    db: Queryable,
  ): Promise<{ walletLedgerId: string; codLedgerId: string }> {
    const result = await db.query<{
      wallet_ledger_id: string;
      cod_ledger_id: string;
    }>(
      `
      SELECT uuid_generate_v7() AS wallet_ledger_id, uuid_generate_v7() AS cod_ledger_id
      `,
    );
    return {
      walletLedgerId: result.rows[0].wallet_ledger_id,
      codLedgerId: result.rows[0].cod_ledger_id,
    };
  }

  async creditWallet(
    walletAccountId: string,
    amount: string,
    db: Queryable,
  ): Promise<string> {
    const result = await db.query<{ available_balance: string }>(
      `
      UPDATE rider_wallet_accounts
      SET available_balance = available_balance + $2::numeric(12,2)
      WHERE wallet_account_id = $1
      RETURNING available_balance::text AS available_balance
      `,
      [walletAccountId, amount],
    );
    return formatInr(result.rows[0].available_balance);
  }

  async debitWallet(
    walletAccountId: string,
    amount: string,
    db: Queryable,
  ): Promise<string | null> {
    const result = await db.query<{ available_balance: string }>(
      `
      UPDATE rider_wallet_accounts
      SET available_balance = available_balance - $2::numeric(12,2)
      WHERE wallet_account_id = $1
        AND available_balance >= $2::numeric(12,2)
      RETURNING available_balance::text AS available_balance
      `,
      [walletAccountId, amount],
    );
    if (!result.rows[0]) {
      return null;
    }
    return formatInr(result.rows[0].available_balance);
  }

  async increaseCod(
    codAccountId: string,
    amount: string,
    db: Queryable,
  ): Promise<string> {
    const result = await db.query<{ cod_due: string }>(
      `
      UPDATE rider_cod_accounts
      SET cod_due = cod_due + $2::numeric(12,2)
      WHERE cod_account_id = $1
      RETURNING cod_due::text AS cod_due
      `,
      [codAccountId, amount],
    );
    return formatInr(result.rows[0].cod_due);
  }

  async decreaseCod(
    codAccountId: string,
    amount: string,
    db: Queryable,
  ): Promise<string | null> {
    const result = await db.query<{ cod_due: string }>(
      `
      UPDATE rider_cod_accounts
      SET cod_due = cod_due - $2::numeric(12,2)
      WHERE cod_account_id = $1
        AND cod_due >= $2::numeric(12,2)
      RETURNING cod_due::text AS cod_due
      `,
      [codAccountId, amount],
    );
    if (!result.rows[0]) {
      return null;
    }
    return formatInr(result.rows[0].cod_due);
  }

  async insertWalletLedger(
    input: {
      walletLedgerId?: string;
      walletAccountId: string;
      direction: 'CREDIT' | 'DEBIT';
      amount: string;
      entryType: WalletEntryType;
      relatedOrderId?: string | null;
      relatedPaymentTransactionId?: string | null;
      relatedCodLedgerId?: string | null;
      actorType: WalletActorType;
      actorProfileId?: string | null;
    },
    db: Queryable,
  ): Promise<WalletLedgerRow> {
    const result = await db.query<WalletLedgerRow>(
      `
      INSERT INTO wallet_ledger_entries (
        wallet_ledger_id,
        wallet_account_id,
        direction,
        amount,
        entry_type,
        related_order_id,
        related_payment_transaction_id,
        related_cod_ledger_id,
        actor_type,
        actor_profile_id
      )
      VALUES (
        COALESCE($1, uuid_generate_v7()),
        $2, $3, $4::numeric(12,2), $5, $6, $7, $8, $9, $10
      )
      RETURNING ${WALLET_LEDGER_COLUMNS}
      `,
      [
        input.walletLedgerId ?? null,
        input.walletAccountId,
        input.direction,
        input.amount,
        input.entryType,
        input.relatedOrderId ?? null,
        input.relatedPaymentTransactionId ?? null,
        input.relatedCodLedgerId ?? null,
        input.actorType,
        input.actorProfileId ?? null,
      ],
    );
    return result.rows[0];
  }

  async insertCodLedger(
    input: {
      codLedgerId?: string;
      codAccountId: string;
      direction: 'INCREASE' | 'DECREASE';
      amount: string;
      source: CodSource;
      relatedOrderId?: string | null;
      relatedWalletLedgerId?: string | null;
      sourceTxnId?: string | null;
    },
    db: Queryable,
  ): Promise<CodLedgerRow> {
    const result = await db.query<CodLedgerRow>(
      `
      INSERT INTO cod_ledger_entries (
        cod_ledger_id,
        cod_account_id,
        direction,
        amount,
        source,
        related_order_id,
        related_wallet_ledger_id,
        source_txn_id
      )
      VALUES (
        COALESCE($1, uuid_generate_v7()),
        $2, $3, $4::numeric(12,2), $5, $6, $7, $8
      )
      RETURNING ${COD_LEDGER_COLUMNS}
      `,
      [
        input.codLedgerId ?? null,
        input.codAccountId,
        input.direction,
        input.amount,
        input.source,
        input.relatedOrderId ?? null,
        input.relatedWalletLedgerId ?? null,
        input.sourceTxnId ?? null,
      ],
    );
    return result.rows[0];
  }

  async operationalStatus(
    riderProfileId: string,
    db: Queryable,
  ): Promise<'CLEAR' | 'SUSPENDED_FOR_COD'> {
    const result = await db.query<{
      cod_operational_status: 'CLEAR' | 'SUSPENDED_FOR_COD';
    }>(
      `
      SELECT cod_operational_status
      FROM rider_profiles
      WHERE rider_profile_id = $1
      `,
      [riderProfileId],
    );
    return result.rows[0]?.cod_operational_status ?? 'CLEAR';
  }

  async syncOperationalStatus(
    riderProfileId: string,
    codDue: string,
    threshold: string,
    db: Queryable,
  ): Promise<'CLEAR' | 'SUSPENDED_FOR_COD'> {
    const suspended = await this.isAtLeast(codDue, threshold, db);
    const status = suspended ? 'SUSPENDED_FOR_COD' : 'CLEAR';
    await db.query(
      `
      UPDATE rider_profiles
      SET cod_operational_status = $2
      WHERE rider_profile_id = $1
      `,
      [riderProfileId, status],
    );
    return status;
  }

  async listWalletLedger(
    walletAccountId: string,
    db: Queryable = this.postgres,
  ): Promise<WalletLedgerRow[]> {
    const result = await db.query<WalletLedgerRow>(
      `
      SELECT ${WALLET_LEDGER_COLUMNS}
      FROM wallet_ledger_entries
      WHERE wallet_account_id = $1
      ORDER BY created_at ASC, wallet_ledger_id ASC
      `,
      [walletAccountId],
    );
    return result.rows;
  }

  async listCodLedger(
    codAccountId: string,
    db: Queryable = this.postgres,
  ): Promise<CodLedgerRow[]> {
    const result = await db.query<CodLedgerRow>(
      `
      SELECT ${COD_LEDGER_COLUMNS}
      FROM cod_ledger_entries
      WHERE cod_account_id = $1
      ORDER BY created_at ASC, cod_ledger_id ASC
      `,
      [codAccountId],
    );
    return result.rows;
  }

  async walletLedgerNet(
    walletAccountId: string,
    db: Queryable,
  ): Promise<string> {
    const result = await db.query<{ net: string }>(
      `
      SELECT COALESCE(SUM(
        CASE WHEN direction = 'CREDIT' THEN amount ELSE -amount END
      ), 0)::text AS net
      FROM wallet_ledger_entries
      WHERE wallet_account_id = $1
      `,
      [walletAccountId],
    );
    return formatInr(result.rows[0].net);
  }

  async codLedgerNet(codAccountId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ net: string }>(
      `
      SELECT COALESCE(SUM(
        CASE WHEN direction = 'INCREASE' THEN amount ELSE -amount END
      ), 0)::text AS net
      FROM cod_ledger_entries
      WHERE cod_account_id = $1
      `,
      [codAccountId],
    );
    return formatInr(result.rows[0].net);
  }

  async cashCollected(orderId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ cash: string }>(
      `
      SELECT COALESCE(SUM(
        CASE
          WHEN method = 'CASH' AND direction = 'CHARGE' AND transaction_status = 'PAID'
            THEN amount
          WHEN method = 'CASH' AND direction = 'REFUND' AND transaction_status = 'REFUNDED'
            THEN -amount
          ELSE 0
        END
      ), 0)::text AS cash
      FROM payment_transactions
      WHERE order_id = $1
      `,
      [orderId],
    );
    return formatInr(result.rows[0].cash);
  }

  async plannedCash(orderId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ planned: string }>(
      `
      SELECT COALESCE(
        customer_planned_cash + receiver_planned_cash,
        0
      )::text AS planned
      FROM order_payment_plans
      WHERE order_id = $1
      `,
      [orderId],
    );
    if (!result.rows[0]) {
      return '0.00';
    }
    return formatInr(result.rows[0].planned);
  }

  async postedCashCompanyShare(
    codAccountId: string,
    orderId: string,
    db: Queryable,
  ): Promise<string> {
    const result = await db.query<{ posted: string }>(
      `
      SELECT COALESCE(SUM(
        CASE WHEN direction = 'INCREASE' THEN amount ELSE -amount END
      ), 0)::text AS posted
      FROM cod_ledger_entries
      WHERE cod_account_id = $1
        AND related_order_id = $2
        AND source = 'CASH_COMPANY_SHARE'
      `,
      [codAccountId, orderId],
    );
    return formatInr(result.rows[0].posted);
  }

  async hasWalletEarningForOrder(
    walletAccountId: string,
    orderId: string,
    db: Queryable,
  ): Promise<boolean> {
    const result = await db.query<{ ok: boolean }>(
      `
      SELECT EXISTS(
        SELECT 1
        FROM wallet_ledger_entries
        WHERE wallet_account_id = $1
          AND related_order_id = $2
          AND entry_type = 'EARNING'
      ) AS ok
      `,
      [walletAccountId, orderId],
    );
    return result.rows[0].ok;
  }

  async hasDigitalEarningSettlement(
    codAccountId: string,
    sourceTxnId: string,
    db: Queryable,
  ): Promise<boolean> {
    const result = await db.query<{ ok: boolean }>(
      `
      SELECT EXISTS(
        SELECT 1
        FROM cod_ledger_entries
        WHERE cod_account_id = $1
          AND source_txn_id = $2
      ) AS ok
      `,
      [codAccountId, sourceTxnId],
    );
    return result.rows[0].ok;
  }

  async listEarnings(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<RiderEarningRow[]> {
    const result = await db.query<RiderEarningRow>(
      `
      SELECT
        s.finance_snapshot_id,
        s.order_id,
        o.display_id,
        s.snapshot_kind,
        s.trip_fare::text AS trip_fare,
        s.rider_amount::text AS rider_amount,
        s.company_commission_amount::text AS company_commission_amount,
        s.operational_cost_amount::text AS operational_cost_amount,
        s.profit_amount::text AS profit_amount,
        s.rider_percentage::text AS rider_percentage,
        s.company_commission_percentage::text AS company_commission_percentage,
        s.frozen_at
      FROM order_finance_snapshots s
      JOIN orders o ON o.order_id = s.order_id
      WHERE o.rider_profile_id = $1
        AND s.snapshot_kind = 'ORIGINAL'
      ORDER BY s.frozen_at ASC, s.finance_snapshot_id ASC
      `,
      [riderProfileId],
    );
    return result.rows;
  }

  async findOriginalSnapshot(
    orderId: string,
    db: Queryable,
  ): Promise<{
    finance_snapshot_id: string;
    rider_amount: string;
    company_commission_amount: string;
    trip_fare: string;
  } | null> {
    const result = await db.query<{
      finance_snapshot_id: string;
      rider_amount: string;
      company_commission_amount: string;
      trip_fare: string;
    }>(
      `
      SELECT
        finance_snapshot_id,
        rider_amount::text AS rider_amount,
        company_commission_amount::text AS company_commission_amount,
        trip_fare::text AS trip_fare
      FROM order_finance_snapshots
      WHERE order_id = $1 AND snapshot_kind = 'ORIGINAL'
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }
}

export function serializeWalletLedger(row: WalletLedgerRow) {
  return {
    wallet_ledger_id: row.wallet_ledger_id,
    direction: row.direction,
    amount: formatInr(row.amount),
    entry_type: row.entry_type,
    related_order_id: row.related_order_id,
    related_payment_transaction_id: row.related_payment_transaction_id,
    related_cod_ledger_id: row.related_cod_ledger_id,
    actor_type: row.actor_type,
    actor_profile_id: row.actor_profile_id,
    created_at: row.created_at.toISOString(),
  };
}

export function serializeCodLedger(row: CodLedgerRow) {
  return {
    cod_ledger_id: row.cod_ledger_id,
    direction: row.direction,
    amount: formatInr(row.amount),
    source: row.source,
    related_order_id: row.related_order_id,
    related_wallet_ledger_id: row.related_wallet_ledger_id,
    created_at: row.created_at.toISOString(),
  };
}

export function serializeEarning(row: RiderEarningRow) {
  return {
    finance_snapshot_id: row.finance_snapshot_id,
    order_id: row.order_id,
    display_id: row.display_id,
    snapshot_kind: row.snapshot_kind,
    trip_fare: formatInr(row.trip_fare),
    rider_amount: formatInr(row.rider_amount),
    company_commission_amount: formatInr(row.company_commission_amount),
    operational_cost_amount: formatInr(row.operational_cost_amount),
    profit_amount: formatInr(row.profit_amount),
    rider_percentage: formatInr(row.rider_percentage),
    company_commission_percentage: formatInr(row.company_commission_percentage),
    frozen_at: row.frozen_at.toISOString(),
    tax: formatInr('0'),
  };
}
