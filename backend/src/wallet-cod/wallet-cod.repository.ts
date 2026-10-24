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
  reverses_wallet_ledger_id?: string | null;
  reversal_reason?: string | null;
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
  reverses_cod_ledger_id?: string | null;
  reversal_reason?: string | null;
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
  | 'RESEND_EARNING'
  | 'REVERSAL';

export type CodSource =
  | 'CASH_COMPANY_SHARE'
  | 'RECHARGE_SETTLEMENT'
  | 'DIGITAL_EARNING_SETTLEMENT'
  | 'CANCELLATION_SHARE_SETTLEMENT'
  | 'ADMIN_ADJUSTMENT'
  | 'REVERSAL';

/** Columns that exist before migration 0032. Existing wallet reads and writes use this list. */
export const WALLET_LEDGER_COLUMNS = `
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

/** Reversal linkage from 0032. Cleanup queries only. */
export const WALLET_LEDGER_REVERSAL_COLUMNS = `
  ${WALLET_LEDGER_COLUMNS},
  reverses_wallet_ledger_id,
  reversal_reason
`;

/** Columns that exist before migration 0032. Existing COD reads and writes use this list. */
export const COD_LEDGER_COLUMNS = `
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

/** Reversal linkage from 0032. Cleanup queries only. */
export const COD_LEDGER_REVERSAL_COLUMNS = `
  ${COD_LEDGER_COLUMNS},
  reverses_cod_ledger_id,
  reversal_reason
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
        AND charge_purpose = 'BOOKING'
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

  /**
   * Authoritative payment-plan totals. Null when no plan row exists.
   * A missing plan is not cash and is not a digital trip.
   */
  async findOrderPaymentPlan(
    orderId: string,
    db: Queryable,
  ): Promise<{ planned_online: string; planned_cash: string } | null> {
    const result = await db.query<{
      planned_online: string;
      planned_cash: string;
    }>(
      `
      SELECT
        (customer_planned_online + receiver_planned_online)::text AS planned_online,
        (customer_planned_cash + receiver_planned_cash)::text AS planned_cash
      FROM order_payment_plans
      WHERE order_id = $1
      `,
      [orderId],
    );
    const row = result.rows[0];
    if (!row) {
      return null;
    }
    return {
      planned_online: formatInr(row.planned_online),
      planned_cash: formatInr(row.planned_cash),
    };
  }

  /**
   * Sum of BOOKING charges marked PAID only after a Cashfree webhook stored
   * SUCCESS on an INR gateway attempt whose amount matches the charge.
   * PENDING, FAILED, and attempts without that SUCCESS row contribute nothing.
   */
  async verifiedOnlineBookingPaid(orderId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ paid: string }>(
      `
      SELECT COALESCE(SUM(t.amount), 0)::text AS paid
      FROM payment_transactions t
      JOIN payment_gateway_attempts g
        ON g.payment_transaction_id = t.payment_transaction_id
      WHERE t.order_id = $1
        AND t.method = 'ONLINE'
        AND t.direction = 'CHARGE'
        AND t.transaction_status = 'PAID'
        AND t.charge_purpose = 'BOOKING'
        AND g.provider = 'cashfree'
        AND g.currency = 'INR'
        AND g.gateway_status = 'SUCCESS'
        AND g.amount = t.amount
      `,
      [orderId],
    );
    return formatInr(result.rows[0].paid);
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

  async findWalletLedgerByPaymentTransactionId(
    paymentTransactionId: string,
    db: Queryable,
  ): Promise<WalletLedgerRow | null> {
    const result = await db.query<WalletLedgerRow>(
      `
      SELECT ${WALLET_LEDGER_COLUMNS}
      FROM wallet_ledger_entries
      WHERE related_payment_transaction_id = $1
      `,
      [paymentTransactionId],
    );
    return result.rows[0] ?? null;
  }

  async findCurrentUpi(
    riderProfileId: string,
    db: Queryable,
  ): Promise<{
    rider_upi_id: string;
    vpa_encrypted_or_token: string;
    vpa_masked: string;
  } | null> {
    const result = await db.query<{
      rider_upi_id: string;
      vpa_encrypted_or_token: string;
      vpa_masked: string;
    }>(
      `
      SELECT rider_upi_id, vpa_encrypted_or_token, vpa_masked
      FROM rider_upis
      WHERE rider_profile_id = $1 AND is_current = TRUE
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  async findCurrentBankAccount(
    riderProfileId: string,
    db: Queryable,
  ): Promise<{
    bank_account_id: string;
    account_encrypted_or_token: string;
    account_masked: string;
    ifsc_or_bank: string | null;
    holder_name: string;
  } | null> {
    const result = await db.query<{
      bank_account_id: string;
      account_encrypted_or_token: string;
      account_masked: string;
      ifsc_or_bank: string | null;
      holder_name: string;
    }>(
      `
      SELECT
        bank_account_id,
        account_encrypted_or_token,
        account_masked,
        ifsc_or_bank,
        holder_name
      FROM rider_bank_accounts
      WHERE rider_profile_id = $1 AND is_current = TRUE
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  async findUpiById(
    riderUpiId: string,
    db: Queryable,
  ): Promise<{
    rider_upi_id: string;
    vpa_encrypted_or_token: string;
    vpa_masked: string;
  } | null> {
    const result = await db.query<{
      rider_upi_id: string;
      vpa_encrypted_or_token: string;
      vpa_masked: string;
    }>(
      `
      SELECT rider_upi_id, vpa_encrypted_or_token, vpa_masked
      FROM rider_upis
      WHERE rider_upi_id = $1
      `,
      [riderUpiId],
    );
    return result.rows[0] ?? null;
  }

  async findBankById(
    bankAccountId: string,
    db: Queryable,
  ): Promise<{
    bank_account_id: string;
    account_encrypted_or_token: string;
    account_masked: string;
    ifsc_or_bank: string | null;
    holder_name: string;
  } | null> {
    const result = await db.query<{
      bank_account_id: string;
      account_encrypted_or_token: string;
      account_masked: string;
      ifsc_or_bank: string | null;
      holder_name: string;
    }>(
      `
      SELECT
        bank_account_id,
        account_encrypted_or_token,
        account_masked,
        ifsc_or_bank,
        holder_name
      FROM rider_bank_accounts
      WHERE bank_account_id = $1
      `,
      [bankAccountId],
    );
    return result.rows[0] ?? null;
  }

  async insertWithdrawal(
    input: {
      riderProfileId: string;
      amount: string;
      payoutMethod: 'UPI' | 'BANK';
      riderUpiId: string | null;
      bankAccountId: string | null;
      walletLedgerId: string;
    },
    db: Queryable,
  ): Promise<{ withdrawal_id: string; status: string }> {
    const result = await db.query<{ withdrawal_id: string; status: string }>(
      `
      INSERT INTO rider_wallet_withdrawals (
        rider_profile_id,
        amount,
        status,
        payout_method,
        rider_upi_id,
        bank_account_id,
        wallet_ledger_id
      )
      VALUES ($1, $2::numeric(12,2), 'REQUESTED', $3, $4, $5, $6)
      RETURNING withdrawal_id, status
      `,
      [
        input.riderProfileId,
        input.amount,
        input.payoutMethod,
        input.riderUpiId,
        input.bankAccountId,
        input.walletLedgerId,
      ],
    );
    return result.rows[0];
  }

  async listWithdrawals(
    db: Queryable = this.postgres,
  ): Promise<
    Array<{
      withdrawal_id: string;
      rider_profile_id: string;
      amount: string;
      status: string;
      payout_method: string;
      rider_upi_id: string | null;
      bank_account_id: string | null;
      merchant_transfer_id: string | null;
      provider_transfer_id: string | null;
      provider_status: string | null;
      failure_reason: string | null;
      requested_at: Date;
      processed_at: Date | null;
      updated_at: Date;
    }>
  > {
    const result = await db.query<{
      withdrawal_id: string;
      rider_profile_id: string;
      amount: string;
      status: string;
      payout_method: string;
      rider_upi_id: string | null;
      bank_account_id: string | null;
      merchant_transfer_id: string | null;
      provider_transfer_id: string | null;
      provider_status: string | null;
      failure_reason: string | null;
      requested_at: Date;
      processed_at: Date | null;
      updated_at: Date;
    }>(
      `
      SELECT
        withdrawal_id,
        rider_profile_id,
        amount::text AS amount,
        status,
        payout_method,
        rider_upi_id,
        bank_account_id,
        merchant_transfer_id,
        provider_transfer_id,
        provider_status,
        failure_reason,
        requested_at,
        processed_at,
        updated_at
      FROM rider_wallet_withdrawals
      ORDER BY requested_at DESC
      LIMIT 200
      `,
    );
    return result.rows;
  }

  async lockWithdrawal(
    withdrawalId: string,
    db: Queryable,
  ): Promise<{
    withdrawal_id: string;
    rider_profile_id: string;
    amount: string;
    status: string;
    payout_method: string;
    rider_upi_id: string | null;
    bank_account_id: string | null;
    wallet_ledger_id: string | null;
    merchant_transfer_id: string | null;
    provider_transfer_id: string | null;
    provider_status: string | null;
    failure_reason: string | null;
    refund_wallet_ledger_id: string | null;
  } | null> {
    const result = await db.query<{
      withdrawal_id: string;
      rider_profile_id: string;
      amount: string;
      status: string;
      payout_method: string;
      rider_upi_id: string | null;
      bank_account_id: string | null;
      wallet_ledger_id: string | null;
      merchant_transfer_id: string | null;
      provider_transfer_id: string | null;
      provider_status: string | null;
      failure_reason: string | null;
      refund_wallet_ledger_id: string | null;
    }>(
      `
      SELECT
        withdrawal_id,
        rider_profile_id,
        amount::text AS amount,
        status,
        payout_method,
        rider_upi_id,
        bank_account_id,
        wallet_ledger_id,
        merchant_transfer_id,
        provider_transfer_id,
        provider_status,
        failure_reason,
        refund_wallet_ledger_id
      FROM rider_wallet_withdrawals
      WHERE withdrawal_id = $1
      FOR UPDATE
      `,
      [withdrawalId],
    );
    return result.rows[0] ?? null;
  }

  async findWithdrawalByMerchantTransferId(
    merchantTransferId: string,
    db: Queryable = this.postgres,
  ): Promise<{ withdrawal_id: string } | null> {
    const result = await db.query<{ withdrawal_id: string }>(
      `
      SELECT withdrawal_id
      FROM rider_wallet_withdrawals
      WHERE merchant_transfer_id = $1
      `,
      [merchantTransferId],
    );
    return result.rows[0] ?? null;
  }

  async listProcessingForReconcile(
    minAgeSeconds: number,
    limit: number,
    db: Queryable = this.postgres,
  ): Promise<Array<{ withdrawal_id: string; merchant_transfer_id: string }>> {
    const result = await db.query<{
      withdrawal_id: string;
      merchant_transfer_id: string;
    }>(
      `
      SELECT withdrawal_id, merchant_transfer_id
      FROM rider_wallet_withdrawals
      WHERE status = 'PROCESSING'
        AND merchant_transfer_id IS NOT NULL
        AND updated_at <= now() - ($1::text || ' seconds')::interval
      ORDER BY updated_at ASC
      LIMIT $2
      `,
      [String(minAgeSeconds), limit],
    );
    return result.rows;
  }

  async updateWithdrawalStatus(
    input: {
      withdrawalId: string;
      status: string;
      decidedByAdminProfileId?: string | null;
      failureReason?: string | null;
      processed?: boolean;
      merchantTransferId?: string | null;
      providerTransferId?: string | null;
      providerStatus?: string | null;
      refundWalletLedgerId?: string | null;
      touchReconciled?: boolean;
    },
    db: Queryable,
  ): Promise<void> {
    await db.query(
      `
      UPDATE rider_wallet_withdrawals
      SET
        status = $2,
        decided_by_admin_profile_id = COALESCE($3, decided_by_admin_profile_id),
        failure_reason = COALESCE($4, failure_reason),
        processed_at = CASE WHEN $5 THEN now() ELSE processed_at END,
        merchant_transfer_id = COALESCE($6, merchant_transfer_id),
        provider_transfer_id = COALESCE($7, provider_transfer_id),
        provider_status = COALESCE($8, provider_status),
        refund_wallet_ledger_id = COALESCE($9, refund_wallet_ledger_id),
        last_reconciled_at = CASE WHEN $10 THEN now() ELSE last_reconciled_at END
      WHERE withdrawal_id = $1
      `,
      [
        input.withdrawalId,
        input.status,
        input.decidedByAdminProfileId ?? null,
        input.failureReason ?? null,
        input.processed === true,
        input.merchantTransferId ?? null,
        input.providerTransferId ?? null,
        input.providerStatus ?? null,
        input.refundWalletLedgerId ?? null,
        input.touchReconciled === true,
      ],
    );
  }

  async listWalletTopUps(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<
    Array<{
      payment_transaction_id: string;
      amount: string;
      transaction_status: string;
      provider_txn_id: string | null;
      created_at: Date;
      gateway_order_id: string | null;
    }>
  > {
    const result = await db.query<{
      payment_transaction_id: string;
      amount: string;
      transaction_status: string;
      provider_txn_id: string | null;
      created_at: Date;
      gateway_order_id: string | null;
    }>(
      `
      SELECT
        t.payment_transaction_id,
        t.amount::text AS amount,
        t.transaction_status,
        t.provider_txn_id,
        t.created_at,
        a.gateway_order_id
      FROM payment_transactions t
      LEFT JOIN payment_gateway_attempts a
        ON a.payment_transaction_id = t.payment_transaction_id
      WHERE t.rider_profile_id = $1
        AND t.charge_purpose = 'WALLET_TOPUP'
      ORDER BY t.created_at DESC
      LIMIT 100
      `,
      [riderProfileId],
    );
    return result.rows;
  }

  async lockWalletLedger(
    ledgerId: string,
    db: Queryable,
  ): Promise<(WalletLedgerRow & { rider_profile_id: string; available_balance: string; ledger_balance: string }) | null> {
    const result = await db.query<
      WalletLedgerRow & { rider_profile_id: string; available_balance: string; ledger_balance: string }
    >(
      `
      SELECT
        e.wallet_ledger_id,
        e.wallet_account_id,
        e.direction,
        e.amount::text AS amount,
        e.entry_type,
        e.related_order_id,
        e.related_payment_transaction_id,
        e.related_cod_ledger_id,
        e.actor_type,
        e.actor_profile_id,
        e.reverses_wallet_ledger_id,
        e.reversal_reason,
        e.created_at,
        a.rider_profile_id,
        a.available_balance::text AS available_balance,
        (
          SELECT COALESCE(SUM(
            CASE WHEN x.direction = 'CREDIT' THEN x.amount ELSE -x.amount END
          ), 0)::text
          FROM wallet_ledger_entries x
          WHERE x.wallet_account_id = e.wallet_account_id
        ) AS ledger_balance
      FROM wallet_ledger_entries e
      JOIN rider_wallet_accounts a ON a.wallet_account_id = e.wallet_account_id
      WHERE e.wallet_ledger_id = $1
      FOR UPDATE OF e, a
      `,
      [ledgerId],
    );
    return result.rows[0] ?? null;
  }

  async findWalletReversal(ledgerId: string, db: Queryable): Promise<WalletLedgerRow | null> {
    const result = await db.query<WalletLedgerRow>(
      `
      SELECT ${WALLET_LEDGER_REVERSAL_COLUMNS}
      FROM wallet_ledger_entries
      WHERE reverses_wallet_ledger_id = $1
      `,
      [ledgerId],
    );
    return result.rows[0] ?? null;
  }

  async lockCodLedger(
    ledgerId: string,
    db: Queryable,
  ): Promise<(CodLedgerRow & { rider_profile_id: string; cod_due: string; ledger_due: string }) | null> {
    const result = await db.query<CodLedgerRow & { rider_profile_id: string; cod_due: string; ledger_due: string }>(
      `
      SELECT
        e.cod_ledger_id,
        e.cod_account_id,
        e.direction,
        e.amount::text AS amount,
        e.source,
        e.related_order_id,
        e.related_wallet_ledger_id,
        e.source_txn_id,
        e.reverses_cod_ledger_id,
        e.reversal_reason,
        e.created_at,
        a.rider_profile_id,
        a.cod_due::text AS cod_due,
        (
          SELECT COALESCE(SUM(
            CASE WHEN x.direction = 'INCREASE' THEN x.amount ELSE -x.amount END
          ), 0)::text
          FROM cod_ledger_entries x
          WHERE x.cod_account_id = e.cod_account_id
        ) AS ledger_due
      FROM cod_ledger_entries e
      JOIN rider_cod_accounts a ON a.cod_account_id = e.cod_account_id
      WHERE e.cod_ledger_id = $1
      FOR UPDATE OF e, a
      `,
      [ledgerId],
    );
    return result.rows[0] ?? null;
  }

  async findCodReversal(ledgerId: string, db: Queryable): Promise<CodLedgerRow | null> {
    const result = await db.query<CodLedgerRow>(
      `
      SELECT ${COD_LEDGER_REVERSAL_COLUMNS}
      FROM cod_ledger_entries
      WHERE reverses_cod_ledger_id = $1
      `,
      [ledgerId],
    );
    return result.rows[0] ?? null;
  }

  async codSourceFor(ledgerId: string, db: Queryable): Promise<string | null> {
    const result = await db.query<{ source: string }>(
      `SELECT source FROM cod_ledger_entries WHERE cod_ledger_id = $1`,
      [ledgerId],
    );
    return result.rows[0]?.source ?? null;
  }

  async walletEntryTypeFor(ledgerId: string, db: Queryable): Promise<string | null> {
    const result = await db.query<{ entry_type: string }>(
      `SELECT entry_type FROM wallet_ledger_entries WHERE wallet_ledger_id = $1`,
      [ledgerId],
    );
    return result.rows[0]?.entry_type ?? null;
  }

  async insertWalletReversal(
    input: {
      walletAccountId: string;
      direction: 'CREDIT' | 'DEBIT';
      amount: string;
      reversesWalletLedgerId: string;
      reason: string;
      actorProfileId: string;
      relatedOrderId?: string | null;
      relatedCodLedgerId?: string | null;
    },
    db: Queryable,
  ): Promise<WalletLedgerRow> {
    const result = await db.query<WalletLedgerRow>(
      `
      INSERT INTO wallet_ledger_entries (
        wallet_account_id, direction, amount, entry_type,
        related_order_id, related_cod_ledger_id,
        actor_type, actor_profile_id,
        reverses_wallet_ledger_id, reversal_reason
      )
      VALUES ($1, $2, $3::numeric(12,2), 'REVERSAL', $4, $5, 'ADMIN', $6, $7, $8)
      RETURNING ${WALLET_LEDGER_REVERSAL_COLUMNS}
      `,
      [
        input.walletAccountId,
        input.direction,
        input.amount,
        input.relatedOrderId ?? null,
        input.relatedCodLedgerId ?? null,
        input.actorProfileId,
        input.reversesWalletLedgerId,
        input.reason.trim(),
      ],
    );
    return result.rows[0];
  }

  async insertCodReversal(
    input: {
      codAccountId: string;
      direction: 'INCREASE' | 'DECREASE';
      amount: string;
      reversesCodLedgerId: string;
      reason: string;
      relatedOrderId?: string | null;
      relatedWalletLedgerId?: string | null;
    },
    db: Queryable,
  ): Promise<CodLedgerRow> {
    const result = await db.query<CodLedgerRow>(
      `
      INSERT INTO cod_ledger_entries (
        cod_account_id, direction, amount, source,
        related_order_id, related_wallet_ledger_id, source_txn_id,
        reverses_cod_ledger_id, reversal_reason
      )
      VALUES (
        $1, $2, $3::numeric(12,2), 'REVERSAL', $4, $5, $6, $7, $8
      )
      RETURNING ${COD_LEDGER_REVERSAL_COLUMNS}
      `,
      [
        input.codAccountId,
        input.direction,
        input.amount,
        input.relatedOrderId ?? null,
        input.relatedWalletLedgerId ?? null,
        `reversal:${input.reversesCodLedgerId}`,
        input.reversesCodLedgerId,
        input.reason.trim(),
      ],
    );
    return result.rows[0];
  }

  async recomputeWalletBalance(walletAccountId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ available_balance: string }>(
      `
      UPDATE rider_wallet_accounts a
      SET available_balance = COALESCE((
        SELECT SUM(CASE WHEN e.direction = 'CREDIT' THEN e.amount ELSE -e.amount END)
        FROM wallet_ledger_entries e
        WHERE e.wallet_account_id = a.wallet_account_id
      ), 0)
      WHERE a.wallet_account_id = $1
      RETURNING available_balance::text AS available_balance
      `,
      [walletAccountId],
    );
    return formatInr(result.rows[0].available_balance);
  }

  async recomputeCodDue(codAccountId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ cod_due: string }>(
      `
      UPDATE rider_cod_accounts a
      SET cod_due = COALESCE((
        SELECT SUM(CASE WHEN e.direction = 'INCREASE' THEN e.amount ELSE -e.amount END)
        FROM cod_ledger_entries e
        WHERE e.cod_account_id = a.cod_account_id
      ), 0)
      WHERE a.cod_account_id = $1
      RETURNING cod_due::text AS cod_due
      `,
      [codAccountId],
    );
    return formatInr(result.rows[0].cod_due);
  }

  async lockCustomerWalletLedger(
    ledgerId: string,
    db: Queryable,
  ): Promise<{
    customer_wallet_ledger_id: string;
    customer_wallet_id: string;
    customer_profile_id: string;
    direction: 'CREDIT' | 'DEBIT';
    amount: string;
    entry_type: string;
    related_order_id: string | null;
    available_balance: string;
    ledger_balance: string;
  } | null> {
    const result = await db.query<{
      customer_wallet_ledger_id: string;
      customer_wallet_id: string;
      customer_profile_id: string;
      direction: 'CREDIT' | 'DEBIT';
      amount: string;
      entry_type: string;
      related_order_id: string | null;
      available_balance: string;
      ledger_balance: string;
    }>(
      `
      SELECT
        e.customer_wallet_ledger_id,
        e.customer_wallet_id,
        a.customer_profile_id,
        e.direction,
        e.amount::text AS amount,
        e.entry_type,
        e.related_order_id,
        a.available_balance::text AS available_balance,
        (
          SELECT COALESCE(SUM(
            CASE WHEN x.direction = 'CREDIT' THEN x.amount ELSE -x.amount END
          ), 0)::text
          FROM customer_wallet_ledger_entries x
          WHERE x.customer_wallet_id = e.customer_wallet_id
        ) AS ledger_balance
      FROM customer_wallet_ledger_entries e
      JOIN customer_wallet_accounts a ON a.customer_wallet_id = e.customer_wallet_id
      WHERE e.customer_wallet_ledger_id = $1
      FOR UPDATE OF e, a
      `,
      [ledgerId],
    );
    return result.rows[0] ?? null;
  }

  async findCustomerWalletReversal(
    ledgerId: string,
    db: Queryable,
  ): Promise<{ customer_wallet_ledger_id: string } | null> {
    const result = await db.query<{ customer_wallet_ledger_id: string }>(
      `
      SELECT customer_wallet_ledger_id
      FROM customer_wallet_ledger_entries
      WHERE reverses_customer_wallet_ledger_id = $1
      `,
      [ledgerId],
    );
    return result.rows[0] ?? null;
  }

  async insertCustomerWalletReversal(
    input: {
      customerWalletId: string;
      direction: 'CREDIT' | 'DEBIT';
      amount: string;
      reversesLedgerId: string;
      reason: string;
      actorProfileId: string;
      relatedOrderId?: string | null;
    },
    db: Queryable,
  ): Promise<{ customer_wallet_ledger_id: string }> {
    const result = await db.query<{ customer_wallet_ledger_id: string }>(
      `
      INSERT INTO customer_wallet_ledger_entries (
        customer_wallet_id, direction, amount, entry_type,
        related_order_id, actor_type, actor_profile_id,
        reverses_customer_wallet_ledger_id, reversal_reason
      )
      VALUES ($1, $2, $3::numeric(12,2), 'REVERSAL', $4, 'ADMIN', $5, $6, $7)
      RETURNING customer_wallet_ledger_id
      `,
      [
        input.customerWalletId,
        input.direction,
        input.amount,
        input.relatedOrderId ?? null,
        input.actorProfileId,
        input.reversesLedgerId,
        input.reason.trim(),
      ],
    );
    return result.rows[0];
  }

  async recomputeCustomerWalletBalance(customerWalletId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ available_balance: string }>(
      `
      UPDATE customer_wallet_accounts a
      SET available_balance = COALESCE((
        SELECT SUM(CASE WHEN e.direction = 'CREDIT' THEN e.amount ELSE -e.amount END)
        FROM customer_wallet_ledger_entries e
        WHERE e.customer_wallet_id = a.customer_wallet_id
      ), 0)
      WHERE a.customer_wallet_id = $1
      RETURNING available_balance::text AS available_balance
      `,
      [customerWalletId],
    );
    return formatInr(result.rows[0].available_balance);
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
