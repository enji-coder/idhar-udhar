import { loadAppConfig } from './configuration';

describe('payment configuration', () => {
  const originalEnv = process.env.NODE_ENV;
  const originalProvider = process.env.PAYMENT_PROVIDER;

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
  });

  it('defaults to unconfigured and does not select a gateway', () => {
    delete process.env.PAYMENT_PROVIDER;
    expect(loadAppConfig().payment.provider).toBe('unconfigured');
  });

  it('keeps unconfigured in production (no sandbox credentials)', () => {
    process.env.NODE_ENV = 'production';
    process.env.PAYMENT_PROVIDER = 'unconfigured';
    expect(loadAppConfig().payment.provider).toBe('unconfigured');
  });

  it('refuses a named vendor, mock capture, or sandbox provider', () => {
    for (const value of ['razorpay', 'cashfree', 'stripe', 'mock', 'sandbox']) {
      process.env.PAYMENT_PROVIDER = value;
      expect(() => loadAppConfig()).toThrow(/PAYMENT_PROVIDER must be unconfigured/);
      expect(() => loadAppConfig()).toThrow(/no online payment vendor/);
    }
  });
});
