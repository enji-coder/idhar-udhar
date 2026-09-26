import { createHash, randomBytes } from 'node:crypto';
import { gatewayAmountToInr } from './cashfree-amount';

export type CashfreeChargeOutcome = 'success' | 'failed' | 'pending';

export type ParsedCashfreeEvent =
  | {
      kind: 'payment';
      eventType: string;
      gatewayOrderId: string;
      orderAmount: string;
      orderCurrency: string;
      paymentAmount: string | null;
      paymentCurrency: string | null;
      outcome: CashfreeChargeOutcome;
      cfPaymentId: string | null;
      failureReason: string | null;
    }
  | {
      kind: 'refund';
      eventType: string;
      gatewayOrderId: string;
      merchantRefundId: string;
      cfRefundId: string | null;
      refundAmount: string;
      refundCurrency: string;
      refundStatus: 'PENDING' | 'SUCCESS' | 'FAILED';
      failureReason: string | null;
    }
  | { kind: 'ignored'; eventType: string };

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function text(value: unknown, max: number): string | null {
  if (typeof value !== 'string' && typeof value !== 'number') {
    return null;
  }
  const raw = String(value).trim();
  if (!raw || raw.length > max) {
    return null;
  }
  return raw;
}

function reason(value: unknown): string | null {
  const raw = text(value, 300);
  if (!raw) {
    return null;
  }
  return raw.replace(/[\r\n]/g, ' ');
}

function currency(value: unknown): string | null {
  const raw = text(value, 8);
  return raw ? raw.toUpperCase() : null;
}

/**
 * Uniqueness is the hash of the signed bytes.
 * `x-idempotency-key` is not part of the HMAC, so it cannot distinguish events.
 */
export function cashfreeEventId(rawBody: string): string {
  return createHash('sha256').update(rawBody).digest('hex');
}

export function newGatewayOrderId(): string {
  return `iu${randomBytes(16).toString('hex')}`;
}

export function merchantRefundId(scopedKey: string): string {
  return `rf${createHash('sha256').update(scopedKey).digest('hex').slice(0, 30)}`;
}

function paymentOutcome(
  eventType: string,
  paymentStatus: string | null,
): CashfreeChargeOutcome | 'reject' {
  if (eventType === 'PAYMENT_SUCCESS_WEBHOOK') {
    return paymentStatus === 'SUCCESS' ? 'success' : 'reject';
  }
  if (eventType === 'PAYMENT_FAILED_WEBHOOK') {
    return paymentStatus === 'FAILED' || paymentStatus === 'CANCELLED'
      ? 'failed'
      : 'reject';
  }
  if (eventType === 'PAYMENT_USER_DROPPED_WEBHOOK') {
    return 'failed';
  }
  return 'reject';
}

function refundStatus(
  raw: string | null,
): 'PENDING' | 'SUCCESS' | 'FAILED' | null {
  if (raw === 'SUCCESS') {
    return 'SUCCESS';
  }
  if (raw === 'PENDING' || raw === 'ONHOLD') {
    return 'PENDING';
  }
  if (raw === 'CANCELLED' || raw === 'FAILED') {
    return 'FAILED';
  }
  return null;
}

export function parseCashfreeWebhook(body: unknown): ParsedCashfreeEvent {
  const root = asRecord(body);
  const eventType = text(root?.type, 80) ?? 'UNKNOWN';
  const data = asRecord(root?.data);
  if (!data) {
    return { kind: 'ignored', eventType };
  }
  if (eventType.startsWith('REFUND')) {
    const refund = asRecord(data.refund);
    const order = asRecord(data.order);
    const gatewayOrderId =
      text(refund?.order_id, 50) ?? text(order?.order_id, 50);
    const merchantRefundId = text(refund?.refund_id, 40);
    const amount = gatewayAmountToInr(refund?.refund_amount);
    const status = refundStatus(text(refund?.refund_status, 32));
    const refundCurrency = currency(refund?.refund_currency) ?? currency(order?.order_currency);
    if (!refund || !gatewayOrderId || !merchantRefundId || !amount || !status || !refundCurrency) {
      return { kind: 'ignored', eventType };
    }
    return {
      kind: 'refund',
      eventType,
      gatewayOrderId,
      merchantRefundId,
      cfRefundId: text(refund.cf_refund_id, 64),
      refundAmount: amount,
      refundCurrency,
      refundStatus: status,
      failureReason: reason(refund.status_description ?? refund.refund_note),
    };
  }

  const order = asRecord(data.order);
  const payment = asRecord(data.payment);
  const gatewayOrderId = text(order?.order_id, 50);
  const orderAmount = gatewayAmountToInr(order?.order_amount);
  const orderCurrency = currency(order?.order_currency);
  if (!gatewayOrderId || !orderAmount || !orderCurrency) {
    return { kind: 'ignored', eventType };
  }
  const paymentStatus = text(payment?.payment_status, 32);
  const outcome = paymentOutcome(eventType, paymentStatus);
  if (outcome === 'reject') {
    return { kind: 'ignored', eventType };
  }
  return {
    kind: 'payment',
    eventType,
    gatewayOrderId,
    orderAmount,
    orderCurrency,
    paymentAmount: payment ? gatewayAmountToInr(payment.payment_amount) : null,
    paymentCurrency: payment ? currency(payment.payment_currency) : null,
    outcome,
    cfPaymentId: text(payment?.cf_payment_id, 64),
    failureReason: reason(payment?.payment_message),
  };
}

export function decideChargeTransition(input: {
  currentStatus: 'PENDING' | 'PAID' | 'FAILED' | 'REFUNDED';
  outcome: CashfreeChargeOutcome;
  amountMatches: boolean;
}): 'apply-paid' | 'apply-failed' | 'ignore' | 'reject' {
  if (!input.amountMatches) {
    return 'reject';
  }
  if (input.outcome === 'pending') {
    return 'ignore';
  }
  if (input.outcome === 'success') {
    return input.currentStatus === 'PENDING' ? 'apply-paid' : 'ignore';
  }
  return input.currentStatus === 'PENDING' ? 'apply-failed' : 'ignore';
}
