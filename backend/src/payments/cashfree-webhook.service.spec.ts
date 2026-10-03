import { CashfreeWebhookService } from './cashfree-webhook.service';
import { ParsedCashfreeEvent } from './cashfree-webhook.parse';

describe('CashfreeWebhookService receivable clearance', () => {
  const payment: ParsedCashfreeEvent = {
    kind: 'payment',
    eventType: 'PAYMENT_SUCCESS_WEBHOOK',
    gatewayOrderId: 'iu-order-1',
    orderAmount: '5.00',
    orderCurrency: 'INR',
    paymentAmount: '5.00',
    paymentCurrency: 'INR',
    outcome: 'success',
    cfPaymentId: 'cf-pay-1',
    failureReason: null,
  };

  it('does not credit the receivable again when the same Cashfree event was already stored', async () => {
    const creditOnlineClearance = jest.fn();
    const tx = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('INSERT INTO payment_webhook_events')) {
          return { rows: [] };
        }
        throw new Error(`unexpected query: ${sql}`);
      }),
    };
    const service = new CashfreeWebhookService(
      { getOrThrow: () => ({}) } as never,
      { transaction: async (work: (db: typeof tx) => Promise<unknown>) => work(tx) } as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      { info: jest.fn() } as never,
      { creditOnlineClearance } as never,
      { applyVerifiedWalletTopUp: jest.fn() } as never,
    );

    await expect(
      service.apply({
        eventId: 'evt-1',
        rawBody: '{"type":"PAYMENT_SUCCESS_WEBHOOK"}',
        parsed: payment,
      }),
    ).resolves.toBe('duplicate');
    expect(creditOnlineClearance).not.toHaveBeenCalled();
  });
});

describe('CashfreeWebhookService wallet top-up', () => {
  const payment: ParsedCashfreeEvent = {
    kind: 'payment',
    eventType: 'PAYMENT_SUCCESS_WEBHOOK',
    gatewayOrderId: 'iu-wallet-1',
    orderAmount: '25.00',
    orderCurrency: 'INR',
    paymentAmount: '25.00',
    paymentCurrency: 'INR',
    outcome: 'success',
    cfPaymentId: 'cf-pay-wallet',
    failureReason: null,
  };

  const attempt = {
    payment_gateway_attempt_id: 'ga-wallet',
    payment_transaction_id: 'pt-wallet',
    provider: 'cashfree',
    environment: 'sandbox' as const,
    gateway_order_id: 'iu-wallet-1',
    cf_order_id: 'cf-order',
    payment_session_id: 'sess',
    gateway_payment_id: null,
    currency: 'INR',
    amount: '25.00',
    gateway_status: 'ACTIVE',
    failure_reason: null,
    order_id: null,
    rider_profile_id: 'rider-1',
    payer_type: 'RIDER' as const,
    transaction_status: 'PENDING' as const,
    transaction_amount: '25.00',
    charge_purpose: 'WALLET_TOPUP' as const,
  };

  function makeWalletWebhookService(
    applyVerifiedWalletTopUp: jest.Mock,
    attemptStatus: 'PENDING' | 'PAID' = 'PENDING',
  ) {
    const tx = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('INSERT INTO payment_webhook_events')) {
          return { rows: [{ event_id: 'evt-wallet' }] };
        }
        if (
          sql.includes('UPDATE payment_transactions') &&
          sql.includes("'PENDING'")
        ) {
          if (attemptStatus === 'PAID') {
            return { rows: [] };
          }
          return { rows: [{ payment_transaction_id: attempt.payment_transaction_id }] };
        }
        if (sql.includes('UPDATE payment_webhook_events')) {
          return { rows: [] };
        }
        throw new Error(`unexpected query: ${sql.slice(0, 80)}`);
      }),
    };
    const gateway = {
      findByGatewayOrder: jest.fn(async () => ({
        ...attempt,
        transaction_status: attemptStatus,
      })),
      updateAttempt: jest.fn(async () => undefined),
    };
    const payments = {
      amountsEqual: jest.fn(async (left: string, right: string) => left === right),
    };
    const service = new CashfreeWebhookService(
      { getOrThrow: () => ({}) } as never,
      { transaction: async (work: (db: typeof tx) => Promise<unknown>) => work(tx) } as never,
      gateway as never,
      payments as never,
      { findById: jest.fn(async () => null) } as never,
      { onTransactionRecorded: jest.fn() } as never,
      { info: jest.fn() } as never,
      { creditOnlineClearance: jest.fn() } as never,
      { applyVerifiedWalletTopUp } as never,
    );
    return { service, applyVerifiedWalletTopUp, gateway };
  }

  it('credits the rider wallet once when Cashfree marks the top-up PAID', async () => {
    const applyVerifiedWalletTopUp = jest.fn(async () => ({
      idempotent_replay: false,
    }));
    const { service, applyVerifiedWalletTopUp: apply } = makeWalletWebhookService(
      applyVerifiedWalletTopUp,
    );
    await expect(
      service.apply({
        eventId: 'evt-wallet-success',
        rawBody: '{"type":"PAYMENT_SUCCESS_WEBHOOK"}',
        parsed: payment,
      }),
    ).resolves.toBe('applied');
    expect(apply).toHaveBeenCalledTimes(1);
    expect(apply).toHaveBeenCalledWith(
      {
        paymentTransactionId: 'pt-wallet',
        riderProfileId: 'rider-1',
        amount: '25.00',
      },
      expect.anything(),
    );
  });

  it('does not credit again when the charge is already PAID', async () => {
    const applyVerifiedWalletTopUp = jest.fn();
    const { service } = makeWalletWebhookService(applyVerifiedWalletTopUp, 'PAID');
    await expect(
      service.apply({
        eventId: 'evt-wallet-replay',
        rawBody: '{"type":"PAYMENT_SUCCESS_WEBHOOK"}',
        parsed: payment,
      }),
    ).resolves.toBe('ignored');
    expect(applyVerifiedWalletTopUp).not.toHaveBeenCalled();
  });
});
