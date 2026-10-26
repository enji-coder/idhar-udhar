import {
  CashfreePaymentService,
  cashfreeTransportErrorFields,
  defaultCashfreeHttp,
  sanitizeCashfreeLogMessage,
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

describe('sanitizeCashfreeLogMessage', () => {
  it('redacts URL credentials, query strings, and secret assignments', () => {
    const logged = sanitizeCashfreeLogMessage(
      'fetch failed https://user:super_secret_value@payments.example/pg/orders?token=super_secret_value Authorization: Bearer super_secret_value x-client-secret=super_secret_value',
    );
    expect(logged).toBe(
      'fetch failed https://***@payments.example/pg/orders Authorization=[redacted] x-client-secret=[redacted]',
    );
    expect(logged).not.toContain('super_secret_value');
    expect(logged.length).toBeLessThanOrEqual(300);
  });

  it('redacts userinfo without a password, fragments, and bare queries', () => {
    const logged = sanitizeCashfreeLogMessage(
      'https://only_user@payments.example/path#access_fragment ?client_id=id_secret&token=query_secret',
    );
    expect(logged).toBe('https://***@payments.example/path ');
    expect(logged).not.toContain('only_user');
    expect(logged).not.toContain('access_fragment');
    expect(logged).not.toContain('id_secret');
    expect(logged).not.toContain('query_secret');
  });

  it('redacts quoted secrets, x-api-key, access tokens, and colon-form bearer/basic', () => {
    const logged = sanitizeCashfreeLogMessage(
      'failed "client_secret":"quoted_secret" x-api-key: api_secret access_token=token_secret Bearer: bearer_secret Basic: basic_secret',
    );
    expect(logged).not.toContain('quoted_secret');
    expect(logged).not.toContain('api_secret');
    expect(logged).not.toContain('token_secret');
    expect(logged).not.toContain('bearer_secret');
    expect(logged).not.toContain('basic_secret');
    expect(logged).toContain('client_secret=[redacted]');
    expect(logged).toContain('x-api-key=[redacted]');
    expect(logged).toContain('access_token=[redacted]');
    expect(logged).toContain('Bearer [redacted]');
    expect(logged).toContain('Basic [redacted]');
  });

  it('redacts the same secret on a second call', () => {
    const first = sanitizeCashfreeLogMessage('Bearer first_secret');
    const second = sanitizeCashfreeLogMessage('Basic second_secret');
    expect(first).toBe('Bearer [redacted]');
    expect(second).toBe('Basic [redacted]');
    expect(first + second).not.toContain('first_secret');
    expect(second).not.toContain('second_secret');
  });
});

describe('defaultCashfreeHttp', () => {
  it('logs allowlisted transport fields and preserves client ApiError', async () => {
    const warn = jest.fn();
    const fetchMock = jest
      .spyOn(globalThis, 'fetch')
      .mockRejectedValue(
        Object.assign(
          new TypeError(
            'fetch failed https://user:super_secret_value@payments.example/pg/orders?token=super_secret_value',
          ),
          {
            cause: Object.assign(
              new Error(
                'connect ECONNREFUSED 1.2.3.4:443 Authorization: Bearer super_secret_value',
              ),
              { code: 'ECONNREFUSED' },
            ),
          },
        ),
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
        error_message: 'fetch failed https://***@payments.example/pg/orders',
        cause_message:
          'connect ECONNREFUSED 1.2.3.4:443 Authorization=[redacted]',
      });
      const logged = JSON.stringify(warn.mock.calls);
      expect(logged).not.toContain('super_secret_value');
      expect(logged).not.toContain('9876543210');
      expect(logged).not.toContain('x-client-id');
      expect(logged).not.toContain('customer_phone');
      expect(logged).not.toContain('api.cashfree.com');
    } finally {
      fetchMock.mockRestore();
    }
  });
});

describe('CashfreePaymentService', () => {
  function serviceWith(environment: 'sandbox' | 'production') {
    const calls: { url: string; headers: Record<string, string>; body?: string }[] = [];
    const config = {
      getOrThrow: () => ({
        provider: 'cashfree',
        cashfree: {
          environment,
          clientId: 'sandbox_client',
          clientSecret: 'sandbox_secret',
          payoutClientId: 'payout_client',
          payoutClientSecret: 'payout_secret',
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
      calls.push({ url, headers: init.headers, body: init.body });
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
    expect(calls[0].headers['x-client-id']).toBe('payout_client');
    expect(calls[0].headers['x-client-secret']).toBe('payout_secret');
    expect(calls[0].headers['x-api-version']).toBe('2024-01-01');
    expect(calls[0].headers['x-client-secret']).not.toBe('sandbox_secret');
    expect(result.outcome).toBe('accepted');
    expect(result.providerTransferId).toBe('cf-transfer-1');
  });

  it('refuses a payout when payout credentials are missing', async () => {
    const config = {
      getOrThrow: () => ({
        provider: 'cashfree',
        cashfree: {
          environment: 'sandbox' as const,
          clientId: 'sandbox_client',
          clientSecret: 'sandbox_secret',
          payoutClientId: null,
          payoutClientSecret: null,
          apiVersion: '2025-01-01',
          apiBaseUrl: 'https://sandbox.cashfree.com/pg',
          payoutApiBaseUrl: 'https://sandbox.cashfree.com/payout',
          payoutApiVersion: '2024-01-01',
          timeoutMs: 1000,
        },
      }),
    };
    const unconfigured = new CashfreePaymentService(
      config as never,
      { query: jest.fn() } as never,
      { info: jest.fn(), warn: jest.fn() } as never,
    );
    const http = jest.fn();
    unconfigured.useHttp(http);
    await expect(
      unconfigured.initiatePayoutTransfer({
        merchantTransferId: 'wabc',
        amount: '25.00',
        payoutMethod: 'UPI',
        beneficiaryId: 'rider1',
        vpa: 'rider@upi',
      }),
    ).rejects.toMatchObject({
      code: 'PAYMENT_PROVIDER_UNAVAILABLE',
      status: 503,
    });
    expect(http).not.toHaveBeenCalled();
  });

  it('registers a UPI beneficiary with the 2024-01-01 body and confirmed id', async () => {
    const { service, calls } = serviceWith('sandbox');
    service.useHttp(async (url, init) => {
      calls.push({ url, headers: init.headers, body: init.body });
      return {
        status: 201,
        json: { beneficiary_id: 'uupi1', beneficiary_status: 'VERIFIED' },
      };
    });
    const result = await service.registerPayoutBeneficiary({
      beneficiaryId: 'uupi1',
      beneficiaryName: 'Ravi Kumar',
      payoutMethod: 'UPI',
      vpa: 'rider@upi',
    });
    expect(result).toEqual({ outcome: 'registered', beneficiaryId: 'uupi1' });
    const body = JSON.parse(calls[0].body ?? '{}') as {
      beneficiary_id: string;
      beneficiary_name: string;
      beneficiary_instrument_details: { vpa?: string; bank_account_number?: string };
    };
    expect(calls[0].url).toBe('https://sandbox.cashfree.com/payout/beneficiary');
    expect(calls[0].headers['x-api-version']).toBe('2024-01-01');
    expect(body).toEqual({
      beneficiary_id: 'uupi1',
      beneficiary_name: 'Ravi Kumar',
      beneficiary_instrument_details: { vpa: 'rider@upi' },
    });
    expect(body.beneficiary_instrument_details.bank_account_number).toBeUndefined();
  });

  it('treats a duplicate beneficiary create as duplicate and a timeout as unknown', async () => {
    const { service } = serviceWith('sandbox');
    service.useHttp(async () => ({ status: 409, json: { message: 'exists' } }));
    await expect(
      service.registerPayoutBeneficiary({
        beneficiaryId: 'uupi1',
        beneficiaryName: 'Ravi Kumar',
        payoutMethod: 'UPI',
        vpa: 'rider@upi',
      }),
    ).resolves.toEqual({ outcome: 'duplicate', beneficiaryId: 'uupi1' });

    const { ApiError } = await import('../common/errors/api-error');
    const { ErrorCodes } = await import('../common/errors/error-codes');
    service.useHttp(async () => {
      throw new ApiError(ErrorCodes.PAYMENT_GATEWAY_REJECTED, 'Cashfree did not respond', 503);
    });
    await expect(
      service.registerPayoutBeneficiary({
        beneficiaryId: 'uupi1',
        beneficiaryName: 'Ravi Kumar',
        payoutMethod: 'UPI',
        vpa: 'rider@upi',
      }),
    ).resolves.toEqual({ outcome: 'unknown', beneficiaryId: null });
  });

  it('sends a transfer only with the supplied registered beneficiary and UPI instrument', async () => {
    const { service, calls } = serviceWith('sandbox');
    service.useHttp(async (url, init) => {
      calls.push({ url, headers: init.headers, body: init.body });
      return { status: 200, json: { status: 'PENDING', cf_transfer_id: 'cf-1' } };
    });
    await service.initiatePayoutTransfer({
      merchantTransferId: 'wabc',
      amount: '25.00',
      payoutMethod: 'UPI',
      beneficiaryId: 'uupi1',
      vpa: 'rider@upi',
    });
    const body = JSON.parse(calls[0].body ?? '{}') as {
      beneficiary_details: {
        beneficiary_id: string;
        beneficiary_instrument_details: { vpa: string };
      };
    };
    expect(body.beneficiary_details.beneficiary_id).toBe('uupi1');
    expect(body.beneficiary_details.beneficiary_instrument_details).toEqual({
      vpa: 'rider@upi',
    });
  });

  it('treats a transport failure as ambiguous after HTTP has started', async () => {
    const { service } = serviceWith('sandbox');
    const { ApiError } = await import('../common/errors/api-error');
    const { ErrorCodes } = await import('../common/errors/error-codes');
    const { PayoutTransferNotDispatchedError } = await import('./cashfree-payment.service');
    const http = jest.fn(async () => {
      throw new ApiError(ErrorCodes.PAYMENT_GATEWAY_REJECTED, 'Cashfree did not respond', 503);
    });
    service.useHttp(http);
    await expect(
      service.initiatePayoutTransfer({
        merchantTransferId: 'wabc',
        amount: '25.00',
        payoutMethod: 'UPI',
        beneficiaryId: 'uupi1',
        vpa: 'rider@upi',
      }),
    ).rejects.toBeInstanceOf(ApiError);
    await expect(
      service.initiatePayoutTransfer({
        merchantTransferId: 'wabc',
        amount: '25.00',
        payoutMethod: 'UPI',
        beneficiaryId: 'uupi1',
        vpa: 'rider@upi',
      }),
    ).rejects.not.toBeInstanceOf(PayoutTransferNotDispatchedError);
    expect(http).toHaveBeenCalled();
  });
});
