import { createHmac } from 'node:crypto';
import { gatewayAmountToInr } from './cashfree-amount';
import { verifyCashfreeWebhookSignature } from './cashfree-signature';
import {
  cashfreeEventId,
  decideChargeTransition,
  parseCashfreeWebhook,
} from './cashfree-webhook.parse';

const SECRET = 'sandbox_secret_not_real';

function sign(rawBody: string, timestamp: string): string {
  return createHmac('sha256', SECRET).update(timestamp + rawBody).digest('base64');
}

describe('Cashfree signature and webhook parsing', () => {
  const now = 1_700_000_000_000;

  it('accepts a signature over the raw body', () => {
    const raw = '{"type":"PAYMENT_SUCCESS_WEBHOOK","data":{"order":{"order_amount":10.5}}}';
    const timestamp = String(now);
    expect(
      verifyCashfreeWebhookSignature({
        secret: SECRET,
        rawBody: raw,
        timestamp,
        signature: sign(raw, timestamp),
        nowMs: now,
      }).ok,
    ).toBe(true);
  });

  it('rejects a signature computed from re-serialized JSON', () => {
    const raw = '{"order_amount":10.50}';
    const timestamp = String(now);
    const altered = JSON.stringify(JSON.parse(raw));
    expect(altered).not.toBe(raw);
    expect(
      verifyCashfreeWebhookSignature({
        secret: SECRET,
        rawBody: raw,
        timestamp,
        signature: sign(altered, timestamp),
        nowMs: now,
      }),
    ).toEqual({ ok: false, reason: 'signature' });
  });

  it('rejects a stale timestamp and a wrong secret', () => {
    const raw = '{}';
    const timestamp = String(now - 73 * 60 * 60 * 1000);
    expect(
      verifyCashfreeWebhookSignature({
        secret: SECRET,
        rawBody: raw,
        timestamp,
        signature: sign(raw, timestamp),
        nowMs: now,
      }),
    ).toEqual({ ok: false, reason: 'timestamp' });
    expect(
      verifyCashfreeWebhookSignature({
        secret: 'other',
        rawBody: raw,
        timestamp: String(now),
        signature: sign(raw, String(now)),
        nowMs: now,
      }),
    ).toEqual({ ok: false, reason: 'signature' });
  });

  it('parses a success webhook and keeps paise', () => {
    const parsed = parseCashfreeWebhook({
      type: 'PAYMENT_SUCCESS_WEBHOOK',
      data: {
        order: { order_id: 'iuorder', order_amount: 10.5, order_currency: 'INR' },
        payment: {
          cf_payment_id: '99',
          payment_status: 'SUCCESS',
          payment_amount: 10.5,
          payment_currency: 'INR',
        },
      },
    });
    expect(parsed).toMatchObject({
      kind: 'payment',
      outcome: 'success',
      orderAmount: '10.50',
      paymentAmount: '10.50',
      cfPaymentId: '99',
    });
  });

  it('does not settle an unsigned event type even when payment_status is SUCCESS', () => {
    const parsed = parseCashfreeWebhook({
      type: 'PAYMENT_CHARGES_WEBHOOK',
      data: {
        order: { order_id: 'iuorder', order_amount: 10, order_currency: 'INR' },
        payment: {
          payment_status: 'SUCCESS',
          payment_amount: 10,
          payment_currency: 'INR',
        },
      },
    });
    expect(parsed.kind).toBe('ignored');
  });

  it('derives the event id from the signed body', () => {
    const raw = '{"type":"PAYMENT_SUCCESS_WEBHOOK"}';
    expect(cashfreeEventId(raw)).toBe(cashfreeEventId(raw));
    expect(cashfreeEventId(raw)).not.toBe(cashfreeEventId(`${raw} `));
  });

  it('does not treat a success event with a failed status as paid', () => {
    const parsed = parseCashfreeWebhook({
      type: 'PAYMENT_SUCCESS_WEBHOOK',
      data: {
        order: { order_id: 'iuorder', order_amount: 10, order_currency: 'INR' },
        payment: { payment_status: 'FAILED', payment_amount: 10, payment_currency: 'INR' },
      },
    });
    expect(parsed.kind).toBe('ignored');
  });

  it('maps user-dropped to a failure and refund success separately', () => {
    const dropped = parseCashfreeWebhook({
      type: 'PAYMENT_USER_DROPPED_WEBHOOK',
      data: {
        order: { order_id: 'iuorder', order_amount: '10.00', order_currency: 'INR' },
      },
    });
    expect(dropped).toMatchObject({ kind: 'payment', outcome: 'failed' });
    const refund = parseCashfreeWebhook({
      type: 'REFUND_STATUS_WEBHOOK',
      data: {
        refund: {
          order_id: 'iuorder',
          refund_id: 'rf123',
          cf_refund_id: '55',
          refund_amount: 4,
          refund_status: 'SUCCESS',
          refund_currency: 'INR',
        },
      },
    });
    expect(refund).toMatchObject({
      kind: 'refund',
      refundStatus: 'SUCCESS',
      refundAmount: '4.00',
    });
  });

  it('rejects an amount mismatch and ignores a replayed success', () => {
    expect(
      decideChargeTransition({
        currentStatus: 'PENDING',
        outcome: 'success',
        amountMatches: false,
      }),
    ).toBe('reject');
    expect(
      decideChargeTransition({
        currentStatus: 'PAID',
        outcome: 'success',
        amountMatches: true,
      }),
    ).toBe('ignore');
    expect(
      decideChargeTransition({
        currentStatus: 'PENDING',
        outcome: 'success',
        amountMatches: true,
      }),
    ).toBe('apply-paid');
    expect(
      decideChargeTransition({
        currentStatus: 'FAILED',
        outcome: 'success',
        amountMatches: true,
      }),
    ).toBe('ignore');
    expect(
      decideChargeTransition({
        currentStatus: 'PENDING',
        outcome: 'failed',
        amountMatches: true,
      }),
    ).toBe('apply-failed');
  });

  it('formats gateway amounts without treating binary floats as authority', () => {
    expect(gatewayAmountToInr(10)).toBe('10.00');
    expect(gatewayAmountToInr('10.5')).toBe('10.50');
    expect(gatewayAmountToInr('10.555')).toBeNull();
  });
});
