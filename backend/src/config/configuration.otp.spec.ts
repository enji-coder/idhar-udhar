import { loadAppConfig } from './configuration';

describe('OTP delivery configuration', () => {
  const originalEnv = process.env.NODE_ENV;
  const originalDelivery = process.env.OTP_DELIVERY_PROVIDER;
  const originalAuthKey = process.env.MSG91_AUTHKEY;
  const originalTemplateId = process.env.MSG91_TEMPLATE_ID;
  const originalSenderId = process.env.MSG91_SENDER_ID;

  function restore(name: string, value: string | undefined): void {
    if (value === undefined) {
      delete process.env[name];
    } else {
      process.env[name] = value;
    }
  }

  afterEach(() => {
    restore('NODE_ENV', originalEnv);
    restore('OTP_DELIVERY_PROVIDER', originalDelivery);
    restore('MSG91_AUTHKEY', originalAuthKey);
    restore('MSG91_TEMPLATE_ID', originalTemplateId);
    restore('MSG91_SENDER_ID', originalSenderId);
  });

  it('keeps capture in non-production when requested', () => {
    process.env.NODE_ENV = 'development';
    process.env.OTP_DELIVERY_PROVIDER = 'capture';
    expect(loadAppConfig().otp.delivery).toBe('capture');
  });

  it('forces unconfigured in production even if capture is requested', () => {
    process.env.NODE_ENV = 'production';
    process.env.OTP_DELIVERY_PROVIDER = 'capture';
    const config = loadAppConfig();
    expect(config.otp.delivery).toBe('unconfigured');
    expect(config.otp.httpPeek).toBe(false);
  });

  it('allows msg91 in production when credentials are present', () => {
    process.env.NODE_ENV = 'production';
    process.env.OTP_DELIVERY_PROVIDER = 'msg91';
    process.env.MSG91_AUTHKEY = 'test-msg91-authkey-not-real';
    process.env.MSG91_TEMPLATE_ID = 'test-msg91-template-id';
    process.env.MSG91_SENDER_ID = 'TESTID';
    const config = loadAppConfig();
    expect(config.otp.delivery).toBe('msg91');
    expect(config.otp.httpPeek).toBe(false);
    expect(config.otp.msg91.templateId).toBe('test-msg91-template-id');
    expect(config.otp.msg91.senderId).toBe('TESTID');
  });

  it('does not enable msg91 in production unless the provider is selected', () => {
    process.env.NODE_ENV = 'production';
    process.env.OTP_DELIVERY_PROVIDER = 'capture';
    process.env.MSG91_AUTHKEY = 'test-msg91-authkey-not-real';
    process.env.MSG91_TEMPLATE_ID = 'test-msg91-template-id';
    process.env.MSG91_SENDER_ID = 'TESTID';
    expect(loadAppConfig().otp.delivery).toBe('unconfigured');
  });

  it('refuses msg91 without credentials and does not fall back', () => {
    process.env.NODE_ENV = 'production';
    process.env.OTP_DELIVERY_PROVIDER = 'msg91';
    delete process.env.MSG91_AUTHKEY;
    process.env.MSG91_TEMPLATE_ID = 'test-msg91-template-id';
    process.env.MSG91_SENDER_ID = 'TESTID';
    expect(() => loadAppConfig()).toThrow(/MSG91_AUTHKEY/);
    expect(() => loadAppConfig()).toThrow(/fall back/);
  });
});
