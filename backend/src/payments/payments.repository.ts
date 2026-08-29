import { Injectable } from '@nestjs/common';
import { formatInr } from '../fare/money';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import {
  PaymentDirection,
  PaymentMethod,
  PayerType,
  TransactionStatus,
  WhoPays,
} from './payment-status';

export type ResponsibilityRow = {
  payment_responsibility_id: string;
  order_id: string;
  applicable_bill_total: string;
  customer_responsibility: string;
  receiver_responsibility: string;
  who_pays: WhoPays;
  created_at: Date;
};

export type PlanRow = {
  payment_plan_id: string;
  order_id: string;
  customer_planned_online: string;
  customer_planned_cash: string;
  receiver_planned_online: string;
  receiver_planned_cash: string;
  created_at: Date;
};

export type TransactionRow = {
  payment_transaction_id: string;
  order_id: string;
  payer_type: PayerType;
  method: PaymentMethod;
  amount: string;
  direction: PaymentDirection;
  transaction_status: TransactionStatus;
  provider_txn_id: string | null;
  provider_event_id: string | null;
  idempotency_key: string;
  created_by_type: 'CUSTOMER' | 'RIDER' | 'ADMIN' | 'WEBHOOK' | 'SYSTEM';
  created_by_profile_id: string | null;
  created_at: Date;
  updated_at: Date;
};

export type PaidTotalsRow = {
  customer_paid: string;
  receiver_paid: string;
  overall_paid: string;
};

export type MethodPolicyRow = {
  cash_enabled: boolean;
  online_enabled: boolean;
};

const RESP_COLUMNS = `
  payment_responsibility_id,
  order_id,
  applicable_bill_total::text AS applicable_bill_total,
  customer_responsibility::text AS customer_responsibility,
  receiver_responsibility::text AS receiver_responsibility,
  who_pays,
  created_at
`;

const PLAN_COLUMNS = `
  payment_plan_id,
  order_id,
  customer_planned_online::text AS customer_planned_online,
  customer_planned_cash::text AS customer_planned_cash,
  receiver_planned_online::text AS receiver_planned_online,
  receiver_planned_cash::text AS receiver_planned_cash,
  created_at
`;

const TX_COLUMNS = `
  payment_transaction_id,
  order_id,
  payer_type,
  method,
  amount::text AS amount,
  direction,
  transaction_status,
  provider_txn_id,
  provider_event_id,
  idempotency_key,
  created_by_type,
  created_by_profile_id,
  created_at,
  updated_at
`;

@Injectable()
export class PaymentsRepository {
  constructor(private readonly postgres: PostgresService) {}

  async findResponsibility(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<ResponsibilityRow | null> {
    const result = await db.query<ResponsibilityRow>(
      `SELECT ${RESP_COLUMNS} FROM order_payment_responsibilities WHERE order_id = $1`,
      [orderId],
    );
    return result.rows[0] ?? null;
  }

  async insertResponsibility(
    input: {
      orderId: string;
      applicableBillTotal: string;
      customerResponsibility: string;
      receiverResponsibility: string;
      whoPays: WhoPays;
    },
    db: Queryable,
  ): Promise<ResponsibilityRow> {
    const result = await db.query<ResponsibilityRow>(
      `
      INSERT INTO order_payment_responsibilities (
        order_id,
        applicable_bill_total,
        customer_responsibility,
        receiver_responsibility,
        who_pays
      )
      VALUES (
        $1,
        $2::numeric(12,2),
        $3::numeric(12,2),
        $4::numeric(12,2),
        $5
      )
      RETURNING ${RESP_COLUMNS}
      `,
      [
        input.orderId,
        input.applicableBillTotal,
        input.customerResponsibility,
        input.receiverResponsibility,
        input.whoPays,
      ],
    );
    return result.rows[0];
  }

  async findPlan(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<PlanRow | null> {
    const result = await db.query<PlanRow>(
      `SELECT ${PLAN_COLUMNS} FROM order_payment_plans WHERE order_id = $1`,
      [orderId],
    );
    return result.rows[0] ?? null;
  }

  async insertPlan(
    input: {
      orderId: string;
      customerPlannedOnline: string;
      customerPlannedCash: string;
      receiverPlannedOnline: string;
      receiverPlannedCash: string;
    },
    db: Queryable,
  ): Promise<PlanRow> {
    const result = await db.query<PlanRow>(
      `
      INSERT INTO order_payment_plans (
        order_id,
        customer_planned_online,
        customer_planned_cash,
        receiver_planned_online,
        receiver_planned_cash
      )
      VALUES (
        $1,
        $2::numeric(12,2),
        $3::numeric(12,2),
        $4::numeric(12,2),
        $5::numeric(12,2)
      )
      RETURNING ${PLAN_COLUMNS}
      `,
      [
        input.orderId,
        input.customerPlannedOnline,
        input.customerPlannedCash,
        input.receiverPlannedOnline,
        input.receiverPlannedCash,
      ],
    );
    return result.rows[0];
  }

  async listTransactions(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<TransactionRow[]> {
    const result = await db.query<TransactionRow>(
      `
      SELECT ${TX_COLUMNS}
      FROM payment_transactions
      WHERE order_id = $1
      ORDER BY created_at ASC, payment_transaction_id ASC
      `,
      [orderId],
    );
    return result.rows;
  }

  async listRecentForAdmin(
    db: Queryable = this.postgres,
  ): Promise<(TransactionRow & { display_id: string })[]> {
    const result = await db.query<TransactionRow & { display_id: string }>(
      `
      SELECT
        t.payment_transaction_id,
        t.order_id,
        t.payer_type,
        t.method,
        t.amount::text AS amount,
        t.direction,
        t.transaction_status,
        t.provider_txn_id,
        t.provider_event_id,
        t.idempotency_key,
        t.created_by_type,
        t.created_by_profile_id,
        t.created_at,
        t.updated_at,
        o.display_id
      FROM payment_transactions t
      JOIN orders o ON o.order_id = t.order_id
      ORDER BY t.created_at DESC
      LIMIT 200
      `,
    );
    return result.rows;
  }

  async insertTransaction(
    input: {
      orderId: string;
      payerType: PayerType;
      method: PaymentMethod;
      amount: string;
      direction: PaymentDirection;
      status: TransactionStatus;
      providerTxnId: string | null;
      providerEventId: string | null;
      idempotencyKey: string;
      createdByType: TransactionRow['created_by_type'];
      createdByProfileId: string | null;
    },
    db: Queryable,
  ): Promise<TransactionRow> {
    const result = await db.query<TransactionRow>(
      `
      INSERT INTO payment_transactions (
        order_id,
        payer_type,
        method,
        amount,
        direction,
        transaction_status,
        provider_txn_id,
        provider_event_id,
        idempotency_key,
        created_by_type,
        created_by_profile_id
      )
      VALUES (
        $1, $2, $3, $4::numeric(12,2), $5, $6, $7, $8, $9, $10, $11
      )
      RETURNING ${TX_COLUMNS}
      `,
      [
        input.orderId,
        input.payerType,
        input.method,
        input.amount,
        input.direction,
        input.status,
        input.providerTxnId,
        input.providerEventId,
        input.idempotencyKey,
        input.createdByType,
        input.createdByProfileId,
      ],
    );
    return result.rows[0];
  }

  async paidTotals(
    orderId: string,
    db: Queryable,
  ): Promise<PaidTotalsRow> {
    const result = await db.query<PaidTotalsRow>(
      `
      SELECT
        COALESCE(SUM(CASE
          WHEN payer_type = 'CUSTOMER' AND direction = 'CHARGE' AND transaction_status = 'PAID'
            THEN amount
          WHEN payer_type = 'CUSTOMER' AND direction = 'REFUND' AND transaction_status = 'REFUNDED'
            THEN -amount
          ELSE 0
        END), 0)::text AS customer_paid,
        COALESCE(SUM(CASE
          WHEN payer_type = 'RECEIVER' AND direction = 'CHARGE' AND transaction_status = 'PAID'
            THEN amount
          WHEN payer_type = 'RECEIVER' AND direction = 'REFUND' AND transaction_status = 'REFUNDED'
            THEN -amount
          ELSE 0
        END), 0)::text AS receiver_paid,
        COALESCE(SUM(CASE
          WHEN direction = 'CHARGE' AND transaction_status = 'PAID' THEN amount
          WHEN direction = 'REFUND' AND transaction_status = 'REFUNDED' THEN -amount
          ELSE 0
        END), 0)::text AS overall_paid
      FROM payment_transactions
      WHERE order_id = $1
      `,
      [orderId],
    );
    return result.rows[0];
  }

  async remainingOwed(
    orderId: string,
    payerType: PayerType,
    db: Queryable,
  ): Promise<string> {
    const result = await db.query<{ remaining: string }>(
      `
      SELECT (
        CASE WHEN $2 = 'CUSTOMER' THEN r.customer_responsibility ELSE r.receiver_responsibility END
        - COALESCE((
          SELECT SUM(CASE
            WHEN direction = 'CHARGE' AND transaction_status = 'PAID' THEN amount
            WHEN direction = 'REFUND' AND transaction_status = 'REFUNDED' THEN -amount
            ELSE 0
          END)
          FROM payment_transactions t
          WHERE t.order_id = r.order_id AND t.payer_type = $2
        ), 0)
      )::text AS remaining
      FROM order_payment_responsibilities r
      WHERE r.order_id = $1
      `,
      [orderId, payerType],
    );
    return result.rows[0]?.remaining ?? '0';
  }

  async amountsEqual(
    left: string,
    right: string,
    db: Queryable,
  ): Promise<boolean> {
    const result = await db.query<{ eq: boolean }>(
      `SELECT $1::numeric(12,2) = $2::numeric(12,2) AS eq`,
      [left, right],
    );
    return result.rows[0]?.eq === true;
  }

  async amountExceeds(
    left: string,
    right: string,
    db: Queryable,
  ): Promise<boolean> {
    const result = await db.query<{ gt: boolean }>(
      `SELECT $1::numeric(12,2) > $2::numeric(12,2) AS gt`,
      [left, right],
    );
    return result.rows[0]?.gt === true;
  }

  async amountsSumTo(
    left: string,
    right: string,
    total: string,
    db: Queryable,
  ): Promise<boolean> {
    const result = await db.query<{ eq: boolean }>(
      `SELECT $1::numeric(12,2) + $2::numeric(12,2) = $3::numeric(12,2) AS eq`,
      [left, right, total],
    );
    return result.rows[0]?.eq === true;
  }

  async findActiveMethodPolicy(
    db: Queryable = this.postgres,
  ): Promise<MethodPolicyRow | null> {
    const result = await db.query<MethodPolicyRow>(
      `
      SELECT cash_enabled, online_enabled
      FROM payment_method_policy_versions
      WHERE status = 'ACTIVE'
      `,
    );
    return result.rows[0] ?? null;
  }
}

export function serializeResponsibility(row: ResponsibilityRow) {
  return {
    payment_responsibility_id: row.payment_responsibility_id,
    order_id: row.order_id,
    applicable_bill_total: formatInr(row.applicable_bill_total),
    customer_responsibility: formatInr(row.customer_responsibility),
    receiver_responsibility: formatInr(row.receiver_responsibility),
    who_pays: row.who_pays,
    created_at: row.created_at.toISOString(),
  };
}

export function serializePlan(row: PlanRow) {
  return {
    payment_plan_id: row.payment_plan_id,
    order_id: row.order_id,
    customer_planned_online: formatInr(row.customer_planned_online),
    customer_planned_cash: formatInr(row.customer_planned_cash),
    receiver_planned_online: formatInr(row.receiver_planned_online),
    receiver_planned_cash: formatInr(row.receiver_planned_cash),
    created_at: row.created_at.toISOString(),
  };
}

export function serializeTransaction(row: TransactionRow) {
  return {
    payment_transaction_id: row.payment_transaction_id,
    order_id: row.order_id,
    payer_type: row.payer_type,
    method: row.method,
    amount: formatInr(row.amount),
    direction: row.direction,
    transaction_status: row.transaction_status,
    created_by_type: row.created_by_type,
    created_at: row.created_at.toISOString(),
    updated_at: row.updated_at.toISOString(),
  };
}
