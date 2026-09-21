import { redactFields } from './app-logger';

describe('redactFields', () => {
  it('redacts OTP, tokens, and password fields', () => {
    const redacted = redactFields({
      otp: '123456',
      password: 'secret-value',
      refresh_token: 'raw-refresh',
      code_hash: 'abc',
      authkey: 'msg91-authkey-must-not-log',
      signed_url: 'https://example.invalid/obj?X-Amz-Signature=secret',
      download_url: 'https://example.invalid/obj?X-Amz-Signature=secret',
      authorization: 'Bearer abc',
      file_contents: 'binary-should-not-log',
      fcm_token: 'fcm-registration-token-must-not-log',
      private_key: '-----BEGIN PRIVATE KEY-----',
      google_maps_api_key: 'AIzaSy-test-key-must-not-log',
      googleApiKey: 'AIzaSy-test-key-must-not-log',
      'x-goog-api-key': 'AIzaSy-test-key-must-not-log',
      signature: 'provider-signature-must-not-log',
      webhook_secret: 'whsec-must-not-log',
      card_number: '4111111111111111',
      cvv: '123',
      upi_id: 'user@upi',
      phone_suffix: '3210',
    });
    expect(redacted).toEqual({
      otp: '[redacted]',
      password: '[redacted]',
      refresh_token: '[redacted]',
      code_hash: '[redacted]',
      authkey: '[redacted]',
      signed_url: '[redacted]',
      download_url: '[redacted]',
      authorization: '[redacted]',
      file_contents: '[redacted]',
      fcm_token: '[redacted]',
      private_key: '[redacted]',
      google_maps_api_key: '[redacted]',
      googleApiKey: '[redacted]',
      'x-goog-api-key': '[redacted]',
      signature: '[redacted]',
      webhook_secret: '[redacted]',
      card_number: '[redacted]',
      cvv: '[redacted]',
      upi_id: '[redacted]',
      phone_suffix: '3210',
    });
  });
});
