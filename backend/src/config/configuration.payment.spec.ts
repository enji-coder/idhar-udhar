import { loadAppConfig } from './configuration';
import { cashfreeApiBaseUrl } from '../payments/cashfree-environment';

const TEST_PAYOUT_KEY = Buffer.alloc(32, 4).toString('base64');

describe('payment configuration', () => {
  const originalEnv = process.env.NODE_ENV;
  const originalProvider = process.env.PAYMENT_PROVIDER;
  const originalEnvironment = process.env.CASHFREE_ENVIRONMENT;
  const originalClientId = process.env.CASHFREE_CLIENT_ID;
  const originalSecret = process.env.CASHFREE_CLIENT_SECRET;
  const originalPayoutClientId = process.env.CASHFREE_PAYOUT_CLIENT_ID;
  const originalPayoutSecret = process.env.CASHFREE_PAYOUT_CLIENT_SECRET;
  const originalTier = process.env.IU_DEPLOYMENT_TIER;
  const originalPayoutKey = process.env.PAYOUT_INSTRUMENT_KEY;

  function restore(name: string, value: string | undefined): void {
    if (value === undefined) {
      delete process.env[name];
    } else {
      process.env[name] = value;
    }
  }

  function useCashfree(environment: 'sandbox' | 'production'): void {
    process.env.PAYMENT_PROVIDER = 'cashfree';
    process.env.CASHFREE_ENVIRONMENT = environment;
    process.env.CASHFREE_CLIENT_ID = 'test_client_id';
    process.env.CASHFREE_CLIENT_SECRET = 'test_client_secret';
    process.env.PAYOUT_INSTRUMENT_KEY = TEST_PAYOUT_KEY;
  }

  afterEach(() => {
    restore('NODE_ENV', originalEnv);
    restore('PAYMENT_PROVIDER', originalProvider);
    restore('CASHFREE_ENVIRONMENT', originalEnvironment);
    restore('CASHFREE_CLIENT_ID', originalClientId);
    restore('CASHFREE_CLIENT_SECRET', originalSecret);
    restore('CASHFREE_PAYOUT_CLIENT_ID', originalPayoutClientId);
    restore('CASHFREE_PAYOUT_CLIENT_SECRET', originalPayoutSecret);
    restore('IU_DEPLOYMENT_TIER', originalTier);
    restore('PAYOUT_INSTRUMENT_KEY', originalPayoutKey);
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
    useCashfree('sandbox');
    const payment = loadAppConfig().payment;
    expect(payment.provider).toBe('cashfree');
    expect(payment.cashfree.environment).toBe('sandbox');
    expect(payment.cashfree.apiBaseUrl).toBe('https://sandbox.cashfree.com/pg');
    expect(payment.cashfree.apiBaseUrl).not.toContain('api.cashfree.com');
  });

  it('selects the Cashfree production host when credentials are present', () => {
    useCashfree('production');
    const payment = loadAppConfig().payment;
    expect(payment.provider).toBe('cashfree');
    expect(payment.cashfree.environment).toBe('production');
    expect(payment.cashfree.apiBaseUrl).toBe('https://api.cashfree.com/pg');
    expect(payment.cashfree.payoutApiBaseUrl).toBe(
      'https://api.cashfree.com/payout',
    );
  });

  it('keeps payout credentials separate from the payment gateway client', () => {
    useCashfree('sandbox');
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

  it('refuses Cashfree credentials that cannot be sent as HTTP headers', () => {
    useCashfree('sandbox');
    process.env.CASHFREE_CLIENT_SECRET = 'test_client_secret\n';
    expect(loadAppConfig().payment.cashfree.clientSecret).toBe('test_client_secret');
    const secret = 'embedded_line_break_secret';
    for (const name of [
      'CASHFREE_CLIENT_ID',
      'CASHFREE_CLIENT_SECRET',
      'CASHFREE_PAYOUT_CLIENT_ID',
      'CASHFREE_PAYOUT_CLIENT_SECRET',
    ]) {
      useCashfree('sandbox');
      process.env.CASHFREE_PAYOUT_CLIENT_ID = 'payout_client_id';
      process.env.CASHFREE_PAYOUT_CLIENT_SECRET = 'payout_client_secret';
      process.env[name] = `${secret}\n${secret}`;
      expect(() => loadAppConfig()).toThrow(new RegExp(name));
      try {
        loadAppConfig();
      } catch (err) {
        expect(String(err)).not.toContain(secret);
      }
      process.env[name] = `nul_${secret}\u0000`;
      expect(() => loadAppConfig()).toThrow(new RegExp(name));
    }
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

  it('allows staging tier only with Cashfree sandbox hosts', () => {
    process.env.IU_DEPLOYMENT_TIER = 'staging';
    useCashfree('sandbox');
    process.env.CASHFREE_CLIENT_ID = 'staging_sandbox_client';
    process.env.CASHFREE_CLIENT_SECRET = 'staging_sandbox_secret';
    const payment = loadAppConfig().payment;
    expect(payment.cashfree.environment).toBe('sandbox');
    expect(payment.cashfree.apiBaseUrl).toBe('https://sandbox.cashfree.com/pg');
  });

  it('refuses staging tier when Cashfree environment is production', () => {
    process.env.IU_DEPLOYMENT_TIER = 'staging';
    process.env.PAYMENT_PROVIDER = 'cashfree';
    process.env.CASHFREE_ENVIRONMENT = 'production';
    process.env.CASHFREE_CLIENT_ID = 'live_client';
    process.env.CASHFREE_CLIENT_SECRET = 'live_secret';
    expect(() => loadAppConfig()).toThrow(
      /IU_DEPLOYMENT_TIER=staging requires CASHFREE_ENVIRONMENT=sandbox/,
    );
  });

  it('requires a 32-byte payout instrument key when Cashfree is selected', () => {
    useCashfree('sandbox');
    delete process.env.PAYOUT_INSTRUMENT_KEY;
    expect(() => loadAppConfig()).toThrow(/PAYOUT_INSTRUMENT_KEY/);
  });

  it('rejects a malformed payout instrument key', () => {
    useCashfree('sandbox');
    process.env.PAYOUT_INSTRUMENT_KEY = Buffer.from('short').toString('base64');
    expect(() => loadAppConfig()).toThrow(/32 bytes/);
  });
});
