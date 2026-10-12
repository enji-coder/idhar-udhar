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
    attemptStatus: 'PENDING' | 'PAID' | 'FAILED' = 'PENDING',
    options?: { duplicateEvent?: boolean; riderProfileId?: string | null },
  ) {
    const tx = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('INSERT INTO payment_webhook_events')) {
          if (options?.duplicateEvent) {
            return { rows: [] };
          }
          return { rows: [{ event_id: 'evt-wallet' }] };
        }
        if (
          sql.includes('UPDATE payment_transactions') &&
          sql.includes("transaction_status = 'PAID'")
        ) {
          // CAS succeeds only from PENDING or FAILED (matches service SQL).
          if (attemptStatus === 'PAID') {
            return { rows: [] };
          }
          if (
            attemptStatus === 'PENDING' ||
            attemptStatus === 'FAILED'
          ) {
            return {
              rows: [{ payment_transaction_id: attempt.payment_transaction_id }],
            };
          }
          return { rows: [] };
        }
        if (
          sql.includes('UPDATE payment_transactions') &&
          sql.includes("transaction_status = 'FAILED'")
        ) {
          if (attemptStatus === 'PENDING') {
            return {
              rows: [{ payment_transaction_id: attempt.payment_transaction_id }],
            };
          }
          return { rows: [] };
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
        rider_profile_id:
          options && 'riderProfileId' in options
            ? options.riderProfileId ?? null
            : attempt.rider_profile_id,
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
    return { service, applyVerifiedWalletTopUp, gateway, tx };
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

  it('settles a delivered booking only after the verified webhook marks it PAID', async () => {
    const syncOrderFinance = jest.fn(async () => undefined);
    const order = {
      order_id: 'order-1',
      rider_profile_id: 'rider-1',
      customer_profile_id: 'customer-1',
      display_id: 'IU-1',
    };
    const tx = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('INSERT INTO payment_webhook_events')) {
          return { rows: [{ event_id: 'evt-booking' }] };
        }
        if (
          sql.includes('UPDATE payment_transactions') &&
          sql.includes("transaction_status = 'PAID'")
        ) {
          return { rows: [{ payment_transaction_id: 'pt-booking' }] };
        }
        if (sql.includes('UPDATE payment_webhook_events')) {
          return { rows: [] };
        }
        throw new Error(`unexpected query: ${sql.slice(0, 80)}`);
      }),
    };
    const service = new CashfreeWebhookService(
      { getOrThrow: () => ({}) } as never,
      { transaction: async (work: (db: typeof tx) => Promise<unknown>) => work(tx) } as never,
      {
        findByGatewayOrder: jest.fn(async () => ({
          ...attempt,
          payment_transaction_id: 'pt-booking',
          gateway_order_id: 'iu-booking-1',
          order_id: 'order-1',
          rider_profile_id: null,
          payer_type: 'CUSTOMER' as const,
          transaction_amount: '100.00',
          charge_purpose: 'BOOKING' as const,
        })),
        updateAttempt: jest.fn(async () => undefined),
      } as never,
      { amountsEqual: jest.fn(async (left: string, right: string) => left === right) } as never,
      { findById: jest.fn(async () => order) } as never,
      { onTransactionRecorded: jest.fn(async () => undefined) } as never,
      { info: jest.fn() } as never,
      { creditOnlineClearance: jest.fn() } as never,
      { applyVerifiedWalletTopUp: jest.fn(), syncOrderFinance } as never,
    );
    await expect(
      service.apply({
        eventId: 'evt-booking-paid',
        rawBody: '{"type":"PAYMENT_SUCCESS_WEBHOOK"}',
        parsed: {
          ...payment,
          gatewayOrderId: 'iu-booking-1',
          orderAmount: '100.00',
          paymentAmount: '100.00',
        },
      }),
    ).resolves.toBe('applied');
    expect(syncOrderFinance).toHaveBeenCalledTimes(1);
    expect(syncOrderFinance).toHaveBeenCalledWith(order, expect.anything());
  });

  it('recovers FAILED to PAID and credits the wallet exactly once', async () => {
    const applyVerifiedWalletTopUp = jest.fn(async () => ({
      idempotent_replay: false,
    }));
    const { service, gateway } = makeWalletWebhookService(
      applyVerifiedWalletTopUp,
      'FAILED',
    );
    await expect(
      service.apply({
        eventId: 'evt-wallet-failed-then-success',
        rawBody: '{"type":"PAYMENT_SUCCESS_WEBHOOK","data":{"recover":true}}',
        parsed: payment,
      }),
    ).resolves.toBe('applied');
    expect(applyVerifiedWalletTopUp).toHaveBeenCalledTimes(1);
    expect(gateway.updateAttempt).toHaveBeenCalledWith(
      expect.objectContaining({ gatewayStatus: 'SUCCESS' }),
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

  it('treats a duplicate SUCCESS event id as duplicate without crediting', async () => {
    const applyVerifiedWalletTopUp = jest.fn();
    const { service } = makeWalletWebhookService(
      applyVerifiedWalletTopUp,
      'FAILED',
      { duplicateEvent: true },
    );
    await expect(
      service.apply({
        eventId: 'evt-wallet-dup',
        rawBody: '{"type":"PAYMENT_SUCCESS_WEBHOOK"}',
        parsed: payment,
      }),
    ).resolves.toBe('duplicate');
    expect(applyVerifiedWalletTopUp).not.toHaveBeenCalled();
  });

  it('ignores a failure webhook after the charge is already PAID', async () => {
    const applyVerifiedWalletTopUp = jest.fn();
    const { service, gateway } = makeWalletWebhookService(
      applyVerifiedWalletTopUp,
      'PAID',
    );
    const failed: ParsedCashfreeEvent = {
      kind: 'payment',
      eventType: 'PAYMENT_FAILED_WEBHOOK',
      gatewayOrderId: 'iu-wallet-1',
      orderAmount: '25.00',
      orderCurrency: 'INR',
      paymentAmount: '25.00',
      paymentCurrency: 'INR',
      outcome: 'failed',
      cfPaymentId: 'cf-pay-wallet',
      failureReason: 'late failure',
    };
    await expect(
      service.apply({
        eventId: 'evt-wallet-late-fail',
        rawBody: '{"type":"PAYMENT_FAILED_WEBHOOK"}',
        parsed: failed,
      }),
    ).resolves.toBe('ignored');
    expect(applyVerifiedWalletTopUp).not.toHaveBeenCalled();
    expect(gateway.updateAttempt).not.toHaveBeenCalled();
  });

  it('rejects SUCCESS recovery when payment amount does not match', async () => {
    const applyVerifiedWalletTopUp = jest.fn();
    const { service } = makeWalletWebhookService(
      applyVerifiedWalletTopUp,
      'FAILED',
    );
    await expect(
      service.apply({
        eventId: 'evt-wallet-bad-amount',
        rawBody: '{"type":"PAYMENT_SUCCESS_WEBHOOK"}',
        parsed: {
          ...payment,
          paymentAmount: '24.00',
        },
      }),
    ).resolves.toBe('rejected');
    expect(applyVerifiedWalletTopUp).not.toHaveBeenCalled();
  });

  it('rejects a SUCCESS WALLET_TOPUP before PAID when rider_profile_id is missing', async () => {
    const applyVerifiedWalletTopUp = jest.fn();
    const { service, gateway, tx } = makeWalletWebhookService(
      applyVerifiedWalletTopUp,
      'PENDING',
      { riderProfileId: null },
    );
    await expect(
      service.apply({
        eventId: 'evt-wallet-missing-rider',
        rawBody: '{"type":"PAYMENT_SUCCESS_WEBHOOK"}',
        parsed: payment,
      }),
    ).resolves.toBe('rejected');
    expect(applyVerifiedWalletTopUp).not.toHaveBeenCalled();
    expect(gateway.updateAttempt).not.toHaveBeenCalled();
    expect(
      tx.query.mock.calls.some(
        ([sql]: [string]) =>
          sql.includes('UPDATE payment_transactions') &&
          sql.includes("transaction_status = 'PAID'"),
      ),
    ).toBe(false);
  });
});
