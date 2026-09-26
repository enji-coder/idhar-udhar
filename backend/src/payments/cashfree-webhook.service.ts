import { createHash } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { isUniqueViolation } from '../common/pg-error';
import { AppLogger } from '../common/logger/app-logger';
import { AppConfig } from '../config/configuration';
import { PostgresService } from '../database/postgres.service';
import { Queryable } from '../database/queryable';
import { PaymentNotificationDispatcher } from '../notifications/payment-notification.dispatcher';
import { OrdersRepository } from '../orders/orders.repository';
import {
  decideChargeTransition,
  ParsedCashfreeEvent,
} from './cashfree-webhook.parse';
import { PaymentGatewayRepository } from './payment-gateway.repository';
import { PaymentsRepository } from './payments.repository';

export type WebhookApplyResult = 'applied' | 'duplicate' | 'ignored' | 'rejected';

@Injectable()
export class CashfreeWebhookService {
  constructor(
    private readonly configService: ConfigService,
    private readonly postgres: PostgresService,
    private readonly gateway: PaymentGatewayRepository,
    private readonly payments: PaymentsRepository,
    private readonly orders: OrdersRepository,
    private readonly notifications: PaymentNotificationDispatcher,
    private readonly logger: AppLogger,
  ) {}

  async apply(input: {
    eventId: string;
    rawBody: string;
    parsed: ParsedCashfreeEvent;
  }): Promise<WebhookApplyResult> {
    const payloadSha256 = createHash('sha256').update(input.rawBody).digest('hex');
    try {
      return await this.postgres.transaction(async (tx) => {
        const inserted = await this.insertEvent(input, payloadSha256, tx);
        if (!inserted) {
          return 'duplicate';
        }
        const result = await this.dispatch(inserted.eventId, input.parsed, tx);
        await tx.query(
          `
          UPDATE payment_webhook_events
          SET
            processing_result = $2,
            payment_transaction_id = $3
          WHERE provider = 'cashfree' AND event_id = $1
          `,
          [
            input.eventId,
            result.result === 'applied'
              ? 'APPLIED'
              : result.result === 'rejected'
                ? 'REJECTED'
                : 'IGNORED',
            result.paymentTransactionId,
          ],
        );
        this.logger.info('cashfree_webhook_processed', {
          event_type: input.parsed.eventType,
          gateway_order_id:
            input.parsed.kind === 'ignored' ? null : input.parsed.gatewayOrderId,
          payment_transaction_id: result.paymentTransactionId,
          result: result.result,
        });
        return result.result;
      });
    } catch (err) {
      if (isUniqueViolation(err, 'pwe_event_unique')) {
        return 'duplicate';
      }
      throw err;
    }
  }

  private async insertEvent(
    input: { eventId: string; parsed: ParsedCashfreeEvent },
    payloadSha256: string,
    tx: Queryable,
  ): Promise<{ eventId: string } | null> {
    const result = await tx.query<{ event_id: string }>(
      `
      INSERT INTO payment_webhook_events (
        provider, event_id, event_type, payload_sha256, processing_result
      )
      VALUES ('cashfree', $1, $2, $3, 'RECEIVED')
      ON CONFLICT (provider, event_id) DO NOTHING
      RETURNING event_id
      `,
      [input.eventId, input.parsed.eventType, payloadSha256],
    );
    return result.rows[0] ? { eventId: result.rows[0].event_id } : null;
  }

  private async dispatch(
    _eventId: string,
    parsed: ParsedCashfreeEvent,
    tx: Queryable,
  ): Promise<{ result: WebhookApplyResult; paymentTransactionId: string | null }> {
    if (parsed.kind === 'ignored') {
      return { result: 'ignored', paymentTransactionId: null };
    }
    if (parsed.kind === 'refund') {
      return this.applyRefund(parsed, tx);
    }
    return this.applyPayment(parsed, tx);
  }

  private async applyPayment(
    parsed: Extract<ParsedCashfreeEvent, { kind: 'payment' }>,
    tx: Queryable,
  ): Promise<{ result: WebhookApplyResult; paymentTransactionId: string | null }> {
    const attempt = await this.gateway.findByGatewayOrder(parsed.gatewayOrderId, tx);
    if (!attempt) {
      if (parsed.gatewayOrderId.startsWith('iu')) {
        throw new Error('cashfree payment webhook arrived before the charge was stored');
      }
      return { result: 'ignored', paymentTransactionId: null };
    }
    const orderAmountMatches =
      parsed.orderCurrency === 'INR' &&
      (await this.payments.amountsEqual(parsed.orderAmount, attempt.transaction_amount, tx));
    const paymentAmountMatches =
      parsed.outcome !== 'success' ||
      (parsed.paymentCurrency === 'INR' &&
        parsed.paymentAmount !== null &&
        (await this.payments.amountsEqual(
          parsed.paymentAmount,
          attempt.transaction_amount,
          tx,
        )));
    const decision = decideChargeTransition({
      currentStatus: attempt.transaction_status,
      outcome: parsed.outcome,
      amountMatches: orderAmountMatches && paymentAmountMatches,
    });
    if (decision === 'reject') {
      return { result: 'rejected', paymentTransactionId: attempt.payment_transaction_id };
    }
    if (decision === 'ignore') {
      return { result: 'ignored', paymentTransactionId: attempt.payment_transaction_id };
    }
    const nextStatus = decision === 'apply-paid' ? 'PAID' : 'FAILED';
    const updated = await tx.query<{ payment_transaction_id: string }>(
      `
      UPDATE payment_transactions
      SET transaction_status = $2
      WHERE payment_transaction_id = $1
        AND transaction_status = 'PENDING'
      RETURNING payment_transaction_id
      `,
      [attempt.payment_transaction_id, nextStatus],
    );
    if (!updated.rows[0]) {
      return { result: 'ignored', paymentTransactionId: attempt.payment_transaction_id };
    }
    await this.gateway.updateAttempt(
      {
        paymentGatewayAttemptId: attempt.payment_gateway_attempt_id,
        gatewayPaymentId: parsed.cfPaymentId,
        gatewayStatus: nextStatus === 'PAID' ? 'SUCCESS' : 'FAILED',
        failureReason: nextStatus === 'FAILED' ? parsed.failureReason : null,
      },
      tx,
    );
    const order = await this.orders.findById(attempt.order_id, tx);
    if (order) {
      await this.notifications.onTransactionRecorded(
        {
          orderId: order.order_id,
          displayId: order.display_id,
          customerProfileId: order.customer_profile_id,
          transactionId: attempt.payment_transaction_id,
          status: nextStatus,
          direction: 'CHARGE',
          amount: attempt.transaction_amount,
        },
        tx,
      );
    }
    return { result: 'applied', paymentTransactionId: attempt.payment_transaction_id };
  }

  private async applyRefund(
    parsed: Extract<ParsedCashfreeEvent, { kind: 'refund' }>,
    tx: Queryable,
  ): Promise<{ result: WebhookApplyResult; paymentTransactionId: string | null }> {
    const refund = await this.gateway.findRefundByMerchantId(parsed.merchantRefundId, tx);
    if (!refund) {
      if (parsed.merchantRefundId.startsWith('rf')) {
        throw new Error('cashfree refund webhook arrived before the refund was stored');
      }
      return { result: 'ignored', paymentTransactionId: null };
    }
    const attempt = await this.gateway.findByGatewayOrder(parsed.gatewayOrderId, tx);
    if (!attempt || attempt.payment_transaction_id !== refund.payment_transaction_id) {
      return { result: 'rejected', paymentTransactionId: refund.payment_transaction_id };
    }
    const amountMatches =
      parsed.refundCurrency === 'INR' &&
      (await this.payments.amountsEqual(parsed.refundAmount, refund.amount, tx));
    if (!amountMatches) {
      return { result: 'rejected', paymentTransactionId: refund.payment_transaction_id };
    }
    if (refund.refund_status === 'SUCCESS' || refund.refund_status === 'FAILED') {
      return { result: 'ignored', paymentTransactionId: refund.payment_transaction_id };
    }
    if (parsed.refundStatus === 'PENDING') {
      await this.gateway.markRefund(
        {
          paymentGatewayRefundId: refund.payment_gateway_refund_id,
          refundStatus: 'PENDING',
          cfRefundId: parsed.cfRefundId,
          refundTransactionId: null,
          failureReason: null,
        },
        tx,
      );
      return { result: 'applied', paymentTransactionId: refund.payment_transaction_id };
    }
    if (parsed.refundStatus === 'FAILED') {
      await this.gateway.markRefund(
        {
          paymentGatewayRefundId: refund.payment_gateway_refund_id,
          refundStatus: 'FAILED',
          cfRefundId: parsed.cfRefundId,
          refundTransactionId: null,
          failureReason: parsed.failureReason,
        },
        tx,
      );
      return { result: 'applied', paymentTransactionId: refund.payment_transaction_id };
    }
    const order = await this.orders.findById(refund.order_id, tx);
    if (!order) {
      return { result: 'rejected', paymentTransactionId: refund.payment_transaction_id };
    }
    const refundTx = await this.payments.insertTransaction(
      {
        orderId: refund.order_id,
        payerType: refund.payer_type,
        method: 'ONLINE',
        amount: refund.amount,
        direction: 'REFUND',
        status: 'REFUNDED',
        providerTxnId: parsed.cfRefundId,
        providerEventId: null,
        idempotencyKey: `cf-refund:${parsed.merchantRefundId}`,
        createdByType: 'WEBHOOK',
        createdByProfileId: null,
      },
      tx,
    );
    await this.gateway.markRefund(
      {
        paymentGatewayRefundId: refund.payment_gateway_refund_id,
        refundStatus: 'SUCCESS',
        cfRefundId: parsed.cfRefundId,
        refundTransactionId: refundTx.payment_transaction_id,
        failureReason: null,
      },
      tx,
    );
    await this.notifications.onTransactionRecorded(
      {
        orderId: order.order_id,
        displayId: order.display_id,
        customerProfileId: order.customer_profile_id,
        transactionId: refundTx.payment_transaction_id,
        status: 'REFUNDED',
        direction: 'REFUND',
        amount: refund.amount,
      },
      tx,
    );
    return { result: 'applied', paymentTransactionId: refund.payment_transaction_id };
  }

  sandboxConfigured(): boolean {
    const payment = this.configService.getOrThrow<AppConfig['payment']>('payment');
    return (
      payment.provider === 'cashfree' &&
      payment.cashfree.environment === 'sandbox' &&
      Boolean(payment.cashfree.clientSecret)
    );
  }
}

export function webhookRejected(): ApiError {
  return new ApiError(
    ErrorCodes.PAYMENT_WEBHOOK_INVALID,
    'Cashfree webhook signature was rejected',
    401,
  );
}
