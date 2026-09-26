import { CashfreePaymentService } from './cashfree-payment.service';

describe('CashfreePaymentService', () => {
  function serviceWith(environment: 'sandbox' | 'production') {
    const calls: { url: string; headers: Record<string, string> }[] = [];
    const config = {
      getOrThrow: () => ({
        provider: 'cashfree',
        cashfree: {
          environment,
          clientId: 'sandbox_client',
          clientSecret: 'sandbox_secret',
          apiVersion: '2025-01-01',
          apiBaseUrl:
            environment === 'sandbox'
              ? 'https://sandbox.cashfree.com/pg'
              : 'https://api.cashfree.com/pg',
          timeoutMs: 1000,
        },
      }),
    };
    const postgres = {
      query: jest.fn(async () => ({
        rows: [
          {
            customer_profile_id: '11111111-1111-1111-1111-111111111111',
            phone_normalized: '9999999999',
          },
        ],
      })),
    };
    const logger = { info: jest.fn(), warn: jest.fn() };
    const service = new CashfreePaymentService(
      config as never,
      postgres as never,
      logger as never,
    );
    service.useHttp(async (url, init) => {
      calls.push({ url, headers: init.headers });
      const body = JSON.parse(init.body ?? '{}') as {
        order_id?: string;
        order_amount?: number;
      };
      return {
        status: 200,
        json: {
          payment_session_id: 'session_test',
          cf_order_id: '2149460581',
          order_id: body.order_id,
          order_amount: body.order_amount,
          order_currency: 'INR',
          order_status: 'ACTIVE',
        },
      };
    });
    return { service, calls };
  }

  it('creates a sandbox order and returns only the checkout session', async () => {
    const { service, calls } = serviceWith('sandbox');
    const result = await service.beginOnlineCharge({
      orderId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      amount: '10.00',
      payerType: 'CUSTOMER',
    });
    expect(calls).toHaveLength(1);
    expect(calls[0].url).toBe('https://sandbox.cashfree.com/pg/orders');
    expect(calls[0].headers['x-client-secret']).toBe('sandbox_secret');
    expect(result.environment).toBe('sandbox');
    expect(result.paymentSessionId).toBe('session_test');
    expect(result.providerTxnId).toBe('2149460581');
    expect(result.providerEventId).toBeNull();
    expect(JSON.stringify(result)).not.toContain('sandbox_secret');
  });

  it('does not call Cashfree when production is selected', async () => {
    const { service, calls } = serviceWith('production');
    await expect(
      service.beginOnlineCharge({
        orderId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        amount: '10.00',
        payerType: 'CUSTOMER',
      }),
    ).rejects.toMatchObject({ status: 503 });
    expect(calls).toHaveLength(0);
  });
});
