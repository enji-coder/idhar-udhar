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
