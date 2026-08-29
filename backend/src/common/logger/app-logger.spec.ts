import { redactFields } from './app-logger';

describe('redactFields', () => {
  it('redacts OTP, tokens, and password fields', () => {
    const redacted = redactFields({
      otp: '123456',
      password: 'secret-value',
      refresh_token: 'raw-refresh',
      code_hash: 'abc',
      phone_suffix: '3210',
    });
    expect(redacted).toEqual({
      otp: '[redacted]',
      password: '[redacted]',
      refresh_token: '[redacted]',
      code_hash: '[redacted]',
      phone_suffix: '3210',
    });
  });
});
