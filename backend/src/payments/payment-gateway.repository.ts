import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { PayerType } from './payment-status';

export type GatewayAttemptRow = {
  payment_gateway_attempt_id: string;
  payment_transaction_id: string;
  provider: string;
  environment: 'sandbox' | 'production';
  gateway_order_id: string;
  cf_order_id: string;
  payment_session_id: string;
  gateway_payment_id: string | null;
  currency: string;
  amount: string;
  gateway_status: string;
  failure_reason: string | null;
  order_id: string;
  payer_type: PayerType;
  transaction_status: 'PENDING' | 'PAID' | 'FAILED' | 'REFUNDED';
  transaction_amount: string;
};

export type RefundableChargeRow = {
  payment_transaction_id: string;
  order_id: string;
  payer_type: PayerType;
  amount: string;
  gateway_order_id: string;
  refundable: string;
};

export type GatewayRefundRow = {
  payment_gateway_refund_id: string;
  payment_transaction_id: string;
  refund_transaction_id: string | null;
  merchant_refund_id: string;
  cf_refund_id: string | null;
  amount: string;
  currency: string;
  refund_status: 'INITIATED' | 'PENDING' | 'SUCCESS' | 'FAILED';
  order_id: string;
  payer_type: PayerType;
};

@Injectable()
export class PaymentGatewayRepository {
  constructor(private readonly postgres: PostgresService) {}

  async insertAttempt(
    input: {
      paymentTransactionId: string;
      environment: 'sandbox' | 'production';
      gatewayOrderId: string;
      cfOrderId: string;
      paymentSessionId: string;
      amount: string;
    },
    db: Queryable,
  ): Promise<void> {
    await db.query(
      `
      INSERT INTO payment_gateway_attempts (
        payment_transaction_id,
        provider,
        environment,
        gateway_order_id,
        cf_order_id,
        payment_session_id,
        currency,
        amount,
        gateway_status
      )
      VALUES ($1, 'cashfree', $2, $3, $4, $5, 'INR', $6::numeric(12,2), 'ACTIVE')
      `,
      [
        input.paymentTransactionId,
        input.environment,
        input.gatewayOrderId,
        input.cfOrderId,
        input.paymentSessionId,
        input.amount,
      ],
    );
  }

  async findByGatewayOrder(
    gatewayOrderId: string,
    db: Queryable = this.postgres,
  ): Promise<GatewayAttemptRow | null> {
    const result = await db.query<GatewayAttemptRow>(
      `
      SELECT
        g.payment_gateway_attempt_id,
        g.payment_transaction_id,
        g.provider,
        g.environment,
        g.gateway_order_id,
        g.cf_order_id,
        g.payment_session_id,
        g.gateway_payment_id,
        g.currency,
        g.amount::text AS amount,
        g.gateway_status,
        g.failure_reason,
        t.order_id,
        t.payer_type,
        t.transaction_status,
        t.amount::text AS transaction_amount
      FROM payment_gateway_attempts g
      JOIN payment_transactions t ON t.payment_transaction_id = g.payment_transaction_id
      WHERE g.provider = 'cashfree' AND g.gateway_order_id = $1
      FOR UPDATE OF t, g
      `,
      [gatewayOrderId],
    );
    return result.rows[0] ?? null;
  }

  async findByTransaction(
    paymentTransactionId: string,
    db: Queryable = this.postgres,
  ): Promise<GatewayAttemptRow | null> {
    const result = await db.query<GatewayAttemptRow>(
      `
      SELECT
        g.payment_gateway_attempt_id,
        g.payment_transaction_id,
        g.provider,
        g.environment,
        g.gateway_order_id,
        g.cf_order_id,
        g.payment_session_id,
        g.gateway_payment_id,
        g.currency,
        g.amount::text AS amount,
        g.gateway_status,
        g.failure_reason,
        t.order_id,
        t.payer_type,
        t.transaction_status,
        t.amount::text AS transaction_amount
      FROM payment_gateway_attempts g
      JOIN payment_transactions t ON t.payment_transaction_id = g.payment_transaction_id
      WHERE g.payment_transaction_id = $1
      `,
      [paymentTransactionId],
    );
    return result.rows[0] ?? null;
  }

  async updateAttempt(
    input: {
      paymentGatewayAttemptId: string;
      gatewayPaymentId: string | null;
      gatewayStatus: string;
      failureReason: string | null;
    },
    db: Queryable,
  ): Promise<void> {
    await db.query(
      `
      UPDATE payment_gateway_attempts
      SET
        gateway_payment_id = COALESCE(gateway_payment_id, $2),
        gateway_status = $3,
        failure_reason = $4
      WHERE payment_gateway_attempt_id = $1
        AND ($2::text IS NULL OR gateway_payment_id IS NULL OR gateway_payment_id = $2)
      `,
      [
        input.paymentGatewayAttemptId,
        input.gatewayPaymentId,
        input.gatewayStatus,
        input.failureReason,
      ],
    );
  }

  async updateGatewayStatus(
    paymentGatewayAttemptId: string,
    gatewayStatus: string,
    db: Queryable,
  ): Promise<void> {
    await db.query(
      `
      UPDATE payment_gateway_attempts
      SET gateway_status = $2
      WHERE payment_gateway_attempt_id = $1
      `,
      [paymentGatewayAttemptId, gatewayStatus],
    );
  }

  async listRefundableCharges(
    orderId: string,
    payerType: PayerType,
    db: Queryable,
  ): Promise<RefundableChargeRow[]> {
    const result = await db.query<RefundableChargeRow>(
      `
      SELECT
        t.payment_transaction_id,
        t.order_id,
        t.payer_type,
        t.amount::text AS amount,
        g.gateway_order_id,
        (
          t.amount - COALESCE((
            SELECT SUM(r.amount)
            FROM payment_gateway_refunds r
            WHERE r.payment_transaction_id = t.payment_transaction_id
              AND r.refund_status <> 'FAILED'
          ), 0)
        )::text AS refundable
      FROM payment_transactions t
      JOIN payment_gateway_attempts g
        ON g.payment_transaction_id = t.payment_transaction_id
      WHERE t.order_id = $1
        AND t.payer_type = $2
        AND t.method = 'ONLINE'
        AND t.direction = 'CHARGE'
        AND t.transaction_status = 'PAID'
      ORDER BY t.created_at, t.payment_transaction_id
      FOR UPDATE OF t
      `,
      [orderId, payerType],
    );
    return result.rows;
  }

  async insertRefund(
    input: {
      paymentTransactionId: string;
      refundTransactionId: string | null;
      merchantRefundId: string;
      cfRefundId: string | null;
      amount: string;
      refundStatus: GatewayRefundRow['refund_status'];
      failureReason: string | null;
    },
    db: Queryable,
  ): Promise<GatewayRefundRow> {
    const result = await db.query<GatewayRefundRow>(
      `
      INSERT INTO payment_gateway_refunds (
        payment_transaction_id,
        refund_transaction_id,
        provider,
        merchant_refund_id,
        cf_refund_id,
        amount,
        currency,
        refund_status,
        failure_reason
      )
      VALUES ($1, $2, 'cashfree', $3, $4, $5::numeric(12,2), 'INR', $6, $7)
      RETURNING
        payment_gateway_refund_id,
        payment_transaction_id,
        refund_transaction_id,
        merchant_refund_id,
        cf_refund_id,
        amount::text AS amount,
        currency,
        refund_status,
        ''::text AS order_id,
        'CUSTOMER'::text AS payer_type
      `,
      [
        input.paymentTransactionId,
        input.refundTransactionId,
        input.merchantRefundId,
        input.cfRefundId,
        input.amount,
        input.refundStatus,
        input.failureReason,
      ],
    );
    return result.rows[0];
  }

  async findRefundByMerchantId(
    merchantRefundId: string,
    db: Queryable,
  ): Promise<GatewayRefundRow | null> {
    const result = await db.query<GatewayRefundRow>(
      `
      SELECT
        r.payment_gateway_refund_id,
        r.payment_transaction_id,
        r.refund_transaction_id,
        r.merchant_refund_id,
        r.cf_refund_id,
        r.amount::text AS amount,
        r.currency,
        r.refund_status,
        t.order_id,
        t.payer_type
      FROM payment_gateway_refunds r
      JOIN payment_transactions t ON t.payment_transaction_id = r.payment_transaction_id
      WHERE r.provider = 'cashfree' AND r.merchant_refund_id = $1
      FOR UPDATE OF r, t
      `,
      [merchantRefundId],
    );
    return result.rows[0] ?? null;
  }

  async markRefund(
    input: {
      paymentGatewayRefundId: string;
      refundStatus: GatewayRefundRow['refund_status'];
      cfRefundId: string | null;
      refundTransactionId: string | null;
      failureReason: string | null;
    },
    db: Queryable,
  ): Promise<void> {
    await db.query(
      `
      UPDATE payment_gateway_refunds
      SET
        refund_status = $2,
        cf_refund_id = COALESCE(cf_refund_id, $3),
        refund_transaction_id = COALESCE(refund_transaction_id, $4),
        failure_reason = $5
      WHERE payment_gateway_refund_id = $1
      `,
      [
        input.paymentGatewayRefundId,
        input.refundStatus,
        input.cfRefundId,
        input.refundTransactionId,
        input.failureReason,
      ],
    );
  }
}
