import {
  CashfreePaymentService,
  cashfreeTransportErrorFields,
  defaultCashfreeHttp,
} from './cashfree-payment.service';

describe('cashfreeTransportErrorFields', () => {
  it('allowlists only safe name/code fields and omits message text', () => {
    const cause = Object.assign(new Error('getaddrinfo ENOTFOUND 1.2.3.4'), {
      code: 'ENOTFOUND',
    });
    const err = Object.assign(new TypeError('fetch failed https://evil.example'), {
      cause,
    });
    expect(cashfreeTransportErrorFields(err)).toEqual({
      error_name: 'TypeError',
      error_code: null,
      cause_name: 'Error',
      cause_code: 'ENOTFOUND',
    });
    expect(JSON.stringify(cashfreeTransportErrorFields(err))).not.toContain(
      'fetch failed',
    );
    expect(JSON.stringify(cashfreeTransportErrorFields(err))).not.toContain(
      '1.2.3.4',
    );
  });

  it('drops codes that are not safe identifiers', () => {
    const err = Object.assign(new Error('x'), {
      code: 'not-a-safe-code',
    });
    expect(cashfreeTransportErrorFields(err).error_code).toBeNull();
  });
});

describe('defaultCashfreeHttp', () => {
  it('logs allowlisted transport fields and preserves client ApiError', async () => {
    const warn = jest.fn();
    const fetchMock = jest
      .spyOn(globalThis, 'fetch')
      .mockRejectedValue(
        Object.assign(new TypeError('fetch failed'), {
          cause: Object.assign(new Error('connect ECONNREFUSED 1.2.3.4:443'), {
            code: 'ECONNREFUSED',
          }),
        }),
      );
    try {
      await expect(
        defaultCashfreeHttp(
          'https://api.cashfree.com/pg/orders',
          {
            method: 'POST',
            headers: {
              'x-client-id': 'cid',
              'x-client-secret': 'super_secret_value',
            },
            body: JSON.stringify({
              customer_details: { customer_phone: '9876543210' },
            }),
            timeoutMs: 1000,
          },
          { warn },
        ),
      ).rejects.toMatchObject({
        code: 'PAYMENT_GATEWAY_REJECTED',
        message: 'Cashfree did not respond',
        status: 503,
      });
      expect(warn).toHaveBeenCalledWith('cashfree_transport_failed', {
        method: 'POST',
        timeout_ms: 1000,
        error_name: 'TypeError',
        error_code: null,
        cause_name: 'Error',
        cause_code: 'ECONNREFUSED',
      });
      const logged = JSON.stringify(warn.mock.calls);
      expect(logged).not.toContain('super_secret_value');
      expect(logged).not.toContain('9876543210');
      expect(logged).not.toContain('fetch failed');
      expect(logged).not.toContain('1.2.3.4');
      expect(logged).not.toContain('api.cashfree.com');
    } finally {
      fetchMock.mockRestore();
    }
  });
});

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
          payoutApiBaseUrl:
            environment === 'sandbox'
              ? 'https://sandbox.cashfree.com/payout'
              : 'https://api.cashfree.com/payout',
          payoutApiVersion: '2024-01-01',
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

  it('creates a production order against the production host', async () => {
    const { service, calls } = serviceWith('production');
    const result = await service.beginOnlineCharge({
      orderId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      amount: '10.00',
      payerType: 'CUSTOMER',
    });
    expect(calls).toHaveLength(1);
    expect(calls[0].url).toBe('https://api.cashfree.com/pg/orders');
    expect(result.environment).toBe('production');
  });

  it('initiates a payout transfer on the payout host', async () => {
    const { service, calls } = serviceWith('sandbox');
    service.useHttp(async (url, init) => {
      calls.push({ url, headers: init.headers });
      return {
        status: 200,
        json: {
          status: 'PENDING',
          cf_transfer_id: 'cf-transfer-1',
          transfer_id: 'wabc',
        },
      };
    });
    const result = await service.initiatePayoutTransfer({
      merchantTransferId: 'wabc',
      amount: '25.00',
      payoutMethod: 'UPI',
      beneficiaryId: 'rider1',
      vpa: 'rider@upi',
    });
    expect(calls[0].url).toBe('https://sandbox.cashfree.com/payout/transfers');
    expect(result.outcome).toBe('accepted');
    expect(result.providerTransferId).toBe('cf-transfer-1');
  });
});
