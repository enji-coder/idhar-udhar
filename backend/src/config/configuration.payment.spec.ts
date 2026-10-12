import { loadAppConfig } from './configuration';
import { cashfreeApiBaseUrl } from '../payments/cashfree-environment';

describe('payment configuration', () => {
  const originalEnv = process.env.NODE_ENV;
  const originalProvider = process.env.PAYMENT_PROVIDER;
  const originalEnvironment = process.env.CASHFREE_ENVIRONMENT;
  const originalClientId = process.env.CASHFREE_CLIENT_ID;
  const originalSecret = process.env.CASHFREE_CLIENT_SECRET;
  const originalPayoutClientId = process.env.CASHFREE_PAYOUT_CLIENT_ID;
  const originalPayoutSecret = process.env.CASHFREE_PAYOUT_CLIENT_SECRET;

  function restore(name: string, value: string | undefined): void {
    if (value === undefined) {
      delete process.env[name];
    } else {
      process.env[name] = value;
    }
  }

  afterEach(() => {
    restore('NODE_ENV', originalEnv);
    restore('PAYMENT_PROVIDER', originalProvider);
    restore('CASHFREE_ENVIRONMENT', originalEnvironment);
    restore('CASHFREE_CLIENT_ID', originalClientId);
    restore('CASHFREE_CLIENT_SECRET', originalSecret);
    restore('CASHFREE_PAYOUT_CLIENT_ID', originalPayoutClientId);
    restore('CASHFREE_PAYOUT_CLIENT_SECRET', originalPayoutSecret);
  });

  it('defaults to unconfigured and does not select a gateway', () => {
    delete process.env.PAYMENT_PROVIDER;
    expect(loadAppConfig().payment.provider).toBe('unconfigured');
    expect(loadAppConfig().payment.cashfree.apiBaseUrl).toBe(
      'https://sandbox.cashfree.com/pg',
    );
  });

  it('keeps unconfigured in production (no sandbox credentials)', () => {
    process.env.NODE_ENV = 'production';
    process.env.PAYMENT_PROVIDER = 'unconfigured';
    expect(loadAppConfig().payment.provider).toBe('unconfigured');
  });

  it('refuses a named vendor or mock capture', () => {
    for (const value of ['razorpay', 'stripe', 'mock', 'sandbox']) {
      process.env.PAYMENT_PROVIDER = value;
      expect(() => loadAppConfig()).toThrow(/PAYMENT_PROVIDER must be unconfigured or cashfree/);
    }
  });

  it('selects the Cashfree sandbox host when credentials are present', () => {
    process.env.PAYMENT_PROVIDER = 'cashfree';
    process.env.CASHFREE_ENVIRONMENT = 'sandbox';
    process.env.CASHFREE_CLIENT_ID = 'test_client_id';
    process.env.CASHFREE_CLIENT_SECRET = 'test_client_secret';
    const payment = loadAppConfig().payment;
    expect(payment.provider).toBe('cashfree');
    expect(payment.cashfree.environment).toBe('sandbox');
    expect(payment.cashfree.apiBaseUrl).toBe('https://sandbox.cashfree.com/pg');
    expect(payment.cashfree.apiBaseUrl).not.toContain('api.cashfree.com');
  });

  it('selects the Cashfree production host when credentials are present', () => {
    process.env.PAYMENT_PROVIDER = 'cashfree';
    process.env.CASHFREE_ENVIRONMENT = 'production';
    process.env.CASHFREE_CLIENT_ID = 'test_client_id';
    process.env.CASHFREE_CLIENT_SECRET = 'test_client_secret';
    const payment = loadAppConfig().payment;
    expect(payment.provider).toBe('cashfree');
    expect(payment.cashfree.environment).toBe('production');
    expect(payment.cashfree.apiBaseUrl).toBe('https://api.cashfree.com/pg');
    expect(payment.cashfree.payoutApiBaseUrl).toBe(
      'https://api.cashfree.com/payout',
    );
  });

  it('keeps payout credentials separate from the payment gateway client', () => {
    process.env.PAYMENT_PROVIDER = 'cashfree';
    process.env.CASHFREE_ENVIRONMENT = 'sandbox';
    process.env.CASHFREE_CLIENT_ID = 'pg_client_id';
    process.env.CASHFREE_CLIENT_SECRET = 'pg_client_secret';
    delete process.env.CASHFREE_PAYOUT_CLIENT_ID;
    delete process.env.CASHFREE_PAYOUT_CLIENT_SECRET;
    const withoutPayout = loadAppConfig().payment.cashfree;
    expect(withoutPayout.clientId).toBe('pg_client_id');
    expect(withoutPayout.clientSecret).toBe('pg_client_secret');
    expect(withoutPayout.payoutClientId).toBeNull();
    expect(withoutPayout.payoutClientSecret).toBeNull();
    expect(withoutPayout.payoutApiBaseUrl).toBe('https://sandbox.cashfree.com/payout');
    expect(withoutPayout.apiBaseUrl).toBe('https://sandbox.cashfree.com/pg');

    process.env.CASHFREE_PAYOUT_CLIENT_ID = 'payout_client_id';
    process.env.CASHFREE_PAYOUT_CLIENT_SECRET = 'payout_client_secret';
    const withPayout = loadAppConfig().payment.cashfree;
    expect(withPayout.clientId).toBe('pg_client_id');
    expect(withPayout.payoutClientId).toBe('payout_client_id');
    expect(withPayout.payoutClientSecret).toBe('payout_client_secret');
    expect(withPayout.payoutClientSecret).not.toBe(withPayout.clientSecret);
  });

  it('requires Cashfree credentials before selecting the gateway', () => {
    process.env.PAYMENT_PROVIDER = 'cashfree';
    process.env.CASHFREE_ENVIRONMENT = 'sandbox';
    process.env.CASHFREE_CLIENT_ID = '';
    process.env.CASHFREE_CLIENT_SECRET = '';
    expect(() => loadAppConfig()).toThrow(/CASHFREE_CLIENT_ID/);
  });

  it('maps the production host without calling it', () => {
    expect(cashfreeApiBaseUrl('sandbox')).toBe('https://sandbox.cashfree.com/pg');
    expect(cashfreeApiBaseUrl('production')).toBe('https://api.cashfree.com/pg');
  });
});
