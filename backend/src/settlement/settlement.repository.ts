import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { formatInr } from '../fare/money';

export type WaitingChargeRow = {
  order_waiting_charge_id: string;
  order_id: string;
  amount: string;
  settlement_status: 'OPEN' | 'SETTLED' | 'VOID';
  initial_waiting_minutes: number;
  waiting_charge_per_minute: string;
  chargeable_minutes: number;
};

/**
 * A VOID waiting assessment stays in the ledger and contributes nothing.
 * Paid credits are not rewritten, and no offsetting credit is invented.
 */
export const RECEIVABLE_OUTSTANDING_CASE = `
  CASE
    WHEN w.settlement_status = 'VOID' THEN 0::numeric(12,2)
    WHEN e.direction = 'CHARGE' THEN e.amount
    ELSE -e.amount
  END
`;

@Injectable()
export class SettlementRepository {
  constructor(private readonly postgres: PostgresService) {}

  async lockCustomerWallet(
    customerProfileId: string,
    db: Queryable,
  ): Promise<{ customer_wallet_id: string; available_balance: string }> {
    await db.query(
      `
      INSERT INTO customer_wallet_accounts (customer_profile_id)
      VALUES ($1)
      ON CONFLICT (customer_profile_id) DO NOTHING
      `,
      [customerProfileId],
    );
    const locked = await db.query<{
      customer_wallet_id: string;
      available_balance: string;
    }>(
      `
      SELECT customer_wallet_id, available_balance::text AS available_balance
      FROM customer_wallet_accounts
      WHERE customer_profile_id = $1
      FOR UPDATE
      `,
      [customerProfileId],
    );
    return locked.rows[0];
  }

  async outstanding(customerProfileId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ outstanding: string }>(
      `
      SELECT GREATEST(
        0::numeric(12,2),
        COALESCE(SUM(${RECEIVABLE_OUTSTANDING_CASE}), 0)
      )::text AS outstanding
      FROM customer_receivable_entries e
      JOIN order_waiting_charges w
        ON w.order_waiting_charge_id = e.order_waiting_charge_id
      WHERE e.customer_profile_id = $1
      `,
      [customerProfileId],
    );
    return formatInr(result.rows[0]?.outstanding ?? '0');
  }

  async orderOutstanding(orderId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ outstanding: string }>(
      `
      SELECT GREATEST(
        0::numeric(12,2),
        COALESCE(SUM(${RECEIVABLE_OUTSTANDING_CASE}), 0)
      )::text AS outstanding
      FROM customer_receivable_entries e
      JOIN order_waiting_charges w
        ON w.order_waiting_charge_id = e.order_waiting_charge_id
      WHERE e.order_id = $1
      `,
      [orderId],
    );
    return formatInr(result.rows[0]?.outstanding ?? '0');
  }

  async findWaiting(
    orderId: string,
    db: Queryable,
  ): Promise<WaitingChargeRow | null> {
    const result = await db.query<WaitingChargeRow>(
      `
      SELECT
        order_waiting_charge_id,
        order_id,
        amount::text AS amount,
        settlement_status,
        initial_waiting_minutes,
        waiting_charge_per_minute::text AS waiting_charge_per_minute,
        chargeable_minutes
      FROM order_waiting_charges
      WHERE order_id = $1
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }

  /**
   * Pickup wait only. Minutes are floored in SQL. A missing arrival still
   * inserts a zero assessment so the order cannot be charged later.
   */
  async assessPickup(orderId: string, db: Queryable): Promise<WaitingChargeRow | null> {
    const existing = await this.findWaiting(orderId, db);
    if (existing) {
      return existing;
    }
    const result = await db.query<WaitingChargeRow>(
      `
      INSERT INTO order_waiting_charges (
        order_id,
        fare_snapshot_id,
        fare_config_version_id,
        arrived_event_id,
        picked_up_event_id,
        elapsed_minutes,
        initial_waiting_minutes,
        waiting_charge_per_minute,
        chargeable_minutes,
        amount
      )
      SELECT
        s.order_id,
        s.fare_snapshot_id,
        s.fare_config_version_id,
        arrived.order_status_event_id,
        picked.order_status_event_id,
        elapsed.minutes,
        s.initial_waiting_minutes,
        s.waiting_charge_per_minute,
        GREATEST(0, elapsed.minutes - s.initial_waiting_minutes),
        ROUND(
          GREATEST(0, elapsed.minutes - s.initial_waiting_minutes)
          * s.waiting_charge_per_minute,
          2
        )
      FROM order_fare_snapshots s
      JOIN LATERAL (
        SELECT order_status_event_id, created_at
        FROM order_status_events
        WHERE order_id = s.order_id AND to_status = 'PICKED_UP'
        ORDER BY created_at ASC
        LIMIT 1
      ) picked ON TRUE
      LEFT JOIN LATERAL (
        SELECT order_status_event_id, created_at
        FROM order_status_events
        WHERE order_id = s.order_id AND to_status = 'ARRIVED_PICKUP'
        ORDER BY created_at ASC
        LIMIT 1
      ) arrived ON TRUE
      CROSS JOIN LATERAL (
        SELECT CASE
          WHEN arrived.created_at IS NULL OR picked.created_at <= arrived.created_at
            THEN 0
          ELSE FLOOR(EXTRACT(EPOCH FROM (picked.created_at - arrived.created_at)) / 60)::integer
        END AS minutes
      ) elapsed
      WHERE s.order_id = $1
      ON CONFLICT (order_id) DO NOTHING
      RETURNING
        order_waiting_charge_id,
        order_id,
        amount::text AS amount,
        settlement_status,
        initial_waiting_minutes,
        waiting_charge_per_minute::text AS waiting_charge_per_minute,
        chargeable_minutes
      `,
      [orderId],
    );
    return result.rows[0] ?? (await this.findWaiting(orderId, db));
  }

  /**
   * Cancels an unpaid OPEN assessment. A credit means the customer already
   * paid, so that row is left untouched. SETTLED rows are not updated.
   */
  async voidOpenWaiting(orderId: string, db: Queryable): Promise<void> {
    await db.query(
      `
      UPDATE order_waiting_charges w
      SET settlement_status = 'VOID'
      WHERE w.order_id = $1
        AND w.settlement_status = 'OPEN'
        AND NOT EXISTS (
          SELECT 1
          FROM customer_receivable_entries e
          WHERE e.order_waiting_charge_id = w.order_waiting_charge_id
            AND e.direction = 'CREDIT'
        )
      `,
      [orderId],
    );
  }

  async markSettled(orderWaitingChargeId: string, db: Queryable): Promise<void> {
    await db.query(
      `
      UPDATE order_waiting_charges
      SET settlement_status = 'SETTLED'
      WHERE order_waiting_charge_id = $1
        AND settlement_status = 'OPEN'
      `,
      [orderWaitingChargeId],
    );
  }

  /**
   * Debit at most the waiting amount and never below zero.
   * Returns the amount actually removed.
   */
  async debitWalletUpTo(
    walletId: string,
    orderId: string,
    maximum: string,
    db: Queryable,
  ): Promise<string> {
    const result = await db.query<{ debited: string }>(
      `
      WITH locked AS (
        SELECT customer_wallet_id, available_balance
        FROM customer_wallet_accounts
        WHERE customer_wallet_id = $1
        FOR UPDATE
      ),
      chosen AS (
        SELECT CASE
          WHEN EXISTS (
            SELECT 1
            FROM customer_wallet_ledger_entries
            WHERE customer_wallet_id = locked.customer_wallet_id
              AND related_order_id = $2
              AND entry_type = 'WAITING_COLLECTION'
          ) THEN 0::numeric(12,2)
          ELSE LEAST(locked.available_balance, $3::numeric(12,2))
        END AS debited
        FROM locked
      ),
      applied AS (
        UPDATE customer_wallet_accounts w
        SET available_balance = w.available_balance - chosen.debited
        FROM locked, chosen
        WHERE w.customer_wallet_id = locked.customer_wallet_id
          AND chosen.debited > 0
        RETURNING chosen.debited
      )
      SELECT COALESCE((SELECT debited::text FROM applied), '0.00') AS debited
      `,
      [walletId, orderId, maximum],
    );
    const debited = formatInr(result.rows[0]?.debited ?? '0');
    if (debited === '0.00') {
      return debited;
    }
    await db.query(
      `
      INSERT INTO customer_wallet_ledger_entries (
        customer_wallet_id, direction, amount, entry_type,
        related_order_id, actor_type
      )
      VALUES ($1, 'DEBIT', $2::numeric(12,2), 'WAITING_COLLECTION', $3, 'SYSTEM')
      ON CONFLICT (customer_wallet_id, related_order_id)
        WHERE entry_type = 'WAITING_COLLECTION' AND related_order_id IS NOT NULL
      DO NOTHING
      `,
      [walletId, debited, orderId],
    );
    return debited;
  }

  async insertReceivable(
    input: {
      customerProfileId: string;
      orderId: string;
      waitingChargeId: string;
      direction: 'CHARGE' | 'CREDIT';
      amount: string;
      entryType: 'WAITING_ASSESSMENT' | 'WALLET_COLLECTION' | 'ONLINE_CLEARANCE';
      idempotencyKey: string;
    },
    db: Queryable,
  ): Promise<boolean> {
    const result = await db.query(
      `
      INSERT INTO customer_receivable_entries (
        customer_profile_id, order_id, order_waiting_charge_id,
        direction, amount, entry_type, idempotency_key
      )
      VALUES ($1, $2, $3, $4, $5::numeric(12,2), $6, $7)
      ON CONFLICT (idempotency_key) DO NOTHING
      RETURNING customer_receivable_entry_id
      `,
      [
        input.customerProfileId,
        input.orderId,
        input.waitingChargeId,
        input.direction,
        input.amount,
        input.entryType,
        input.idempotencyKey,
      ],
    );
    return Boolean(result.rows[0]);
  }

  async receivableCredits(orderId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ credits: string }>(
      `
      SELECT COALESCE(SUM(amount), 0)::text AS credits
      FROM customer_receivable_entries
      WHERE order_id = $1
        AND direction = 'CREDIT'
      `,
      [orderId],
    );
    return formatInr(result.rows[0]?.credits ?? '0');
  }

  async bookingCustomerPaid(orderId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ paid: string }>(
      `
      SELECT COALESCE(SUM(
        CASE
          WHEN direction = 'CHARGE' AND transaction_status = 'PAID' THEN amount
          WHEN direction = 'REFUND' AND transaction_status = 'REFUNDED' THEN -amount
          ELSE 0
        END
      ), 0)::text AS paid
      FROM payment_transactions
      WHERE order_id = $1
        AND payer_type = 'CUSTOMER'
        AND charge_purpose = 'BOOKING'
      `,
      [orderId],
    );
    return formatInr(result.rows[0]?.paid ?? '0');
  }

  async bookingReceiverPaid(orderId: string, db: Queryable): Promise<string> {
    const result = await db.query<{ paid: string }>(
      `
      SELECT COALESCE(SUM(
        CASE
          WHEN direction = 'CHARGE' AND transaction_status = 'PAID' THEN amount
          WHEN direction = 'REFUND' AND transaction_status = 'REFUNDED' THEN -amount
          ELSE 0
        END
      ), 0)::text AS paid
      FROM payment_transactions
      WHERE order_id = $1
        AND payer_type = 'RECEIVER'
        AND charge_purpose = 'BOOKING'
      `,
      [orderId],
    );
    return formatInr(result.rows[0]?.paid ?? '0');
  }

  async insertInvoice(
    input: {
      invoiceNumber: string;
      orderId: string;
      tripFare: string;
      additional: string;
      billedTotal: string;
      customerPaid: string;
      receiverPaid: string;
      paymentStatus: 'UNPAID' | 'PARTIALLY_PAID' | 'PAID';
    },
    db: Queryable,
  ): Promise<void> {
    const inserted = await db.query<{ invoice_id: string }>(
      `
      INSERT INTO invoices (
        invoice_number, order_id, status, issued_at,
        trip_fare, discount, additional_locked_charges, rounding, billed_total,
        customer_paid, receiver_paid, gst_on_fare, payment_status_snapshot
      )
      VALUES (
        $1, $2, 'ISSUED', now(),
        $3::numeric(12,2), 0, $4::numeric(12,2), 0, $5::numeric(12,2),
        $6::numeric(12,2), $7::numeric(12,2), 0, $8
      )
      ON CONFLICT (order_id) DO NOTHING
      RETURNING invoice_id
      `,
      [
        input.invoiceNumber,
        input.orderId,
        input.tripFare,
        input.additional,
        input.billedTotal,
        input.customerPaid,
        input.receiverPaid,
        input.paymentStatus,
      ],
    );
    const invoiceId = inserted.rows[0]?.invoice_id;
    if (!invoiceId) {
      return;
    }
    await db.query(
      `
      INSERT INTO invoice_lines (invoice_id, sequence, line_type, label, amount)
      VALUES ($1, 0, 'TRIP_FARE', 'Trip Fare', $2::numeric(12,2))
      `,
      [invoiceId, input.tripFare],
    );
    if (input.additional !== '0.00') {
      await db.query(
        `
        INSERT INTO invoice_lines (invoice_id, sequence, line_type, label, amount)
        VALUES ($1, 1, 'WAITING', 'Waiting Charges', $2::numeric(12,2))
        `,
        [invoiceId, input.additional],
      );
    }
  }

  async markInvoicePaidIfSettled(orderId: string, db: Queryable): Promise<void> {
    const outstanding = await this.orderOutstanding(orderId, db);
    if (outstanding !== '0.00') {
      return;
    }
    await db.query(
      `
      UPDATE invoices
      SET payment_status_snapshot = 'PAID'
      WHERE order_id = $1
        AND status = 'ISSUED'
        AND payment_status_snapshot IS DISTINCT FROM 'PAID'
      `,
      [orderId],
    );
  }
}
