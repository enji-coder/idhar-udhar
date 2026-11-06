import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { formatInr } from '../fare/money';
import { InvoiceHeaderRecord, InvoiceLineRecord } from './invoice-document';

/** Inserts one invoice. A repeat delivery does not update the stored row. */
export const INVOICE_INSERT_SQL = `
      INSERT INTO invoices (
        invoice_number, order_id, status, issued_at,
        trip_fare, discount, additional_locked_charges, rounding, billed_total,
        customer_paid, receiver_paid, gst_on_fare, payment_status_snapshot
      )
      SELECT
        $1, o.order_id, 'ISSUED', now(),
        $3::numeric(12,2), $9::numeric(12,2), $4::numeric(12,2), $10::numeric(12,2), $5::numeric(12,2),
        $6::numeric(12,2), $7::numeric(12,2), 0, $8
      FROM orders o
      WHERE o.order_id = $2
        AND o.canonical_status = 'DELIVERED'
      ON CONFLICT (order_id) DO NOTHING
      RETURNING invoice_id
      `;

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

  async lockOrderStatus(orderId: string, db: Queryable): Promise<string | null> {
    const result = await db.query<{ canonical_status: string }>(
      `
      SELECT canonical_status
      FROM orders
      WHERE order_id = $1
      FOR UPDATE
      `,
      [orderId],
    );
    return result.rows[0]?.canonical_status ?? null;
  }

  async insertInvoice(
    input: {
      invoiceNumber: string;
      orderId: string;
      tripFare: string;
      discount?: string;
      rounding?: string;
      additional: string;
      billedTotal: string;
      customerPaid: string;
      receiverPaid: string;
      paymentStatus: 'UNPAID' | 'PARTIALLY_PAID' | 'PAID';
    },
    db: Queryable,
  ): Promise<void> {
    const discount = input.discount ?? '0.00';
    const rounding = input.rounding ?? '0.00';
    const inserted = await db.query<{ invoice_id: string }>(INVOICE_INSERT_SQL, [
      input.invoiceNumber,
      input.orderId,
      input.tripFare,
      input.additional,
      input.billedTotal,
      input.customerPaid,
      input.receiverPaid,
      input.paymentStatus,
      discount,
      rounding,
    ]);
    const invoiceId = inserted.rows[0]?.invoice_id;
    if (!invoiceId) {
      return;
    }
    const lines: Array<{ sequence: number; lineType: string; label: string; amount: string }> = [
      { sequence: 0, lineType: 'TRIP_FARE', label: 'Trip Fare', amount: input.tripFare },
    ];
    let sequence = 1;
    if (discount !== '0.00') {
      lines.push({
        sequence,
        lineType: 'DISCOUNT',
        label: 'Discount',
        amount: discount,
      });
      sequence += 1;
    }
    if (input.additional !== '0.00') {
      lines.push({
        sequence,
        lineType: 'WAITING',
        label: 'Waiting Charges',
        amount: input.additional,
      });
      sequence += 1;
    }
    if (rounding !== '0.00') {
      lines.push({
        sequence,
        lineType: 'ROUNDING',
        label: 'Rounding',
        amount: rounding,
      });
    }
    for (const line of lines) {
      await db.query(
        `
        INSERT INTO invoice_lines (invoice_id, sequence, line_type, label, amount)
        VALUES ($1, $2, $3, $4, $5::numeric(12,2))
        `,
        [invoiceId, line.sequence, line.lineType, line.label, line.amount],
      );
    }
  }

  async findInvoiceAccess(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<{
    order_id: string;
    customer_profile_id: string;
    canonical_status: string;
    crn: string;
  } | null> {
    const result = await db.query<{
      order_id: string;
      customer_profile_id: string;
      canonical_status: string;
      crn: string;
    }>(
      `
      SELECT order_id, customer_profile_id, canonical_status, crn
      FROM orders
      WHERE order_id = $1
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }

  async findInvoiceHeader(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<InvoiceHeaderRecord | null> {
    const result = await db.query<InvoiceHeaderRecord>(
      `
      SELECT
        i.invoice_number,
        i.status,
        i.issued_at,
        i.trip_fare::text AS trip_fare,
        i.discount::text AS discount,
        i.additional_locked_charges::text AS additional_locked_charges,
        i.rounding::text AS rounding,
        i.billed_total::text AS billed_total,
        i.customer_paid::text AS customer_paid,
        i.receiver_paid::text AS receiver_paid,
        i.payment_status_snapshot,
        o.order_id,
        o.crn,
        o.canonical_status,
        pickup.address_text AS pickup_address,
        pickup.contact_name AS pickup_contact_name,
        pickup.contact_phone AS pickup_contact_phone,
        drop_stop.address_text AS drop_address,
        drop_stop.contact_name AS drop_contact_name,
        drop_stop.contact_phone AS drop_contact_phone,
        drop_stop.completed_at AS trip_completed_at,
        o.vehicle_category_name_snapshot AS vehicle_category,
        vehicle.registration AS vehicle_registration,
        plan.customer_planned_online::text AS customer_planned_online,
        plan.customer_planned_cash::text AS customer_planned_cash,
        plan.receiver_planned_online::text AS receiver_planned_online,
        plan.receiver_planned_cash::text AS receiver_planned_cash
      FROM invoices i
      JOIN orders o ON o.order_id = i.order_id
      LEFT JOIN LATERAL (
        SELECT address_text, contact_name, contact_phone
        FROM order_stops
        WHERE order_id = o.order_id AND stop_type = 'PICKUP'
        ORDER BY sequence ASC
        LIMIT 1
      ) pickup ON TRUE
      LEFT JOIN LATERAL (
        SELECT address_text, contact_name, contact_phone, completed_at
        FROM order_stops
        WHERE order_id = o.order_id AND stop_type = 'DROP'
        ORDER BY sequence DESC
        LIMIT 1
      ) drop_stop ON TRUE
      LEFT JOIN LATERAL (
        SELECT registration
        FROM vehicles
        WHERE rider_profile_id = o.rider_profile_id
          AND active = TRUE
        ORDER BY created_at DESC
        LIMIT 1
      ) vehicle ON TRUE
      LEFT JOIN order_payment_plans plan ON plan.order_id = o.order_id
      WHERE i.order_id = $1
        AND o.canonical_status = 'DELIVERED'
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }

  async findInvoiceLines(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<InvoiceLineRecord[]> {
    const result = await db.query<InvoiceLineRecord>(
      `
      SELECT l.sequence, l.line_type, l.label, l.amount::text AS amount
      FROM invoice_lines l
      JOIN invoices i ON i.invoice_id = l.invoice_id
      WHERE i.order_id = $1
      ORDER BY l.sequence ASC
      `,
      [orderId],
    );
    return result.rows;
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

  /**
   * Read-only pickup-wait facts. Does not insert a charge.
   * The persisted assessment remains assessPickup at PICKED_UP.
   */
  async loadPickupWaitFacts(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<PickupWaitFacts | null> {
    const result = await db.query<PickupWaitFacts>(
      `
      SELECT
        s.initial_waiting_minutes,
        s.waiting_charge_per_minute::text AS waiting_charge_per_minute,
        arrived.created_at AS arrived_at,
        picked.created_at AS picked_up_at,
        now() AS server_now,
        categories.name AS vehicle_category_name,
        categories.vehicle AS vehicle,
        waiting.amount::text AS assessed_amount,
        waiting.chargeable_minutes AS assessed_chargeable_minutes,
        waiting.elapsed_minutes AS assessed_elapsed_minutes,
        waiting.settlement_status AS assessed_settlement_status,
        waiting.initial_waiting_minutes AS assessed_initial_waiting_minutes,
        waiting.waiting_charge_per_minute::text AS assessed_waiting_charge_per_minute
      FROM order_fare_snapshots s
      JOIN orders o ON o.order_id = s.order_id
      LEFT JOIN vehicle_categories categories
        ON categories.vehicle_category_id = o.vehicle_category_id
      LEFT JOIN LATERAL (
        SELECT created_at
        FROM order_status_events
        WHERE order_id = s.order_id AND to_status = 'ARRIVED_PICKUP'
        ORDER BY created_at ASC
        LIMIT 1
      ) arrived ON TRUE
      LEFT JOIN LATERAL (
        SELECT created_at
        FROM order_status_events
        WHERE order_id = s.order_id AND to_status = 'PICKED_UP'
        ORDER BY created_at ASC
        LIMIT 1
      ) picked ON TRUE
      LEFT JOIN order_waiting_charges waiting
        ON waiting.order_id = s.order_id
      WHERE s.order_id = $1
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }
}

export type PickupWaitFacts = {
  initial_waiting_minutes: number;
  waiting_charge_per_minute: string;
  arrived_at: Date | null;
  picked_up_at: Date | null;
  server_now: Date;
  vehicle_category_name: string | null;
  vehicle: string | null;
  assessed_amount: string | null;
  assessed_chargeable_minutes: number | null;
  assessed_elapsed_minutes: number | null;
  assessed_settlement_status: 'OPEN' | 'SETTLED' | 'VOID' | null;
  assessed_initial_waiting_minutes: number | null;
  assessed_waiting_charge_per_minute: string | null;
};
