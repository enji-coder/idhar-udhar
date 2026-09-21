import { loadAppConfig } from './configuration';

const FAKE_SERVICE_ACCOUNT = JSON.stringify({
  type: 'service_account',
  project_id: 'idhar-udhar-5dd89',
  private_key_id: 'test',
  private_key:
    '-----BEGIN PRIVATE KEY-----\nMIIBFAKE\n-----END PRIVATE KEY-----\n',
  client_email: 'firebase-adminsdk-test@idhar-udhar-5dd89.iam.gserviceaccount.com',
  client_id: '1',
  token_uri: 'https://oauth2.googleapis.com/token',
});

describe('FCM push provider configuration', () => {
  const originalEnv = process.env.NODE_ENV;
  const originalPush = process.env.PUSH_PROVIDER;
  const originalJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

  function restore(name: string, value: string | undefined): void {
    if (value === undefined) {
      delete process.env[name];
    } else {
      process.env[name] = value;
    }
  }

  afterEach(() => {
    restore('NODE_ENV', originalEnv);
    restore('PUSH_PROVIDER', originalPush);
    restore('FIREBASE_SERVICE_ACCOUNT_JSON', originalJson);
  });

  it('keeps capture in non-production when requested', () => {
    process.env.NODE_ENV = 'development';
    process.env.PUSH_PROVIDER = 'capture';
    delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    expect(loadAppConfig().notifications.pushProvider).toBe('capture');
  });

  it('forces unconfigured in production even if capture is requested', () => {
    process.env.NODE_ENV = 'production';
    process.env.PUSH_PROVIDER = 'capture';
    delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    expect(loadAppConfig().notifications.pushProvider).toBe('unconfigured');
  });

  it('defaults to unconfigured in production when push provider is unset', () => {
    process.env.NODE_ENV = 'production';
    delete process.env.PUSH_PROVIDER;
    delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    expect(loadAppConfig().notifications.pushProvider).toBe('unconfigured');
  });

  it('allows fcm in production when the service-account JSON is present', () => {
    process.env.NODE_ENV = 'production';
    process.env.PUSH_PROVIDER = 'fcm';
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON = FAKE_SERVICE_ACCOUNT;
    const config = loadAppConfig();
    expect(config.notifications.pushProvider).toBe('fcm');
    expect(JSON.stringify(config)).not.toContain('BEGIN PRIVATE KEY');
    expect(JSON.stringify(config)).not.toContain('firebase-adminsdk-test');
  });

  it('refuses fcm without FIREBASE_SERVICE_ACCOUNT_JSON and does not fall back', () => {
    process.env.NODE_ENV = 'production';
    process.env.PUSH_PROVIDER = 'fcm';
    delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    expect(() => loadAppConfig()).toThrow(/FIREBASE_SERVICE_ACCOUNT_JSON/);
    expect(() => loadAppConfig()).toThrow(/fall back/);
  });
});
