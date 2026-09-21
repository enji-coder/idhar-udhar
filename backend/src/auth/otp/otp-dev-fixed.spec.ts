import { isDevCaptureDummyOtp } from './otp-dev-fixed';

describe('isDevCaptureDummyOtp', () => {
  it('accepts any 4-digit code in non-production capture mode', () => {
    for (const code of ['1234', '5678', '0000', '4321']) {
      expect(
        isDevCaptureDummyOtp({
          code,
          nodeEnv: 'development',
          delivery: 'capture',
        }),
      ).toBe(true);
    }
    expect(
      isDevCaptureDummyOtp({
        code: '9999',
        nodeEnv: 'test',
        delivery: 'capture',
      }),
    ).toBe(true);
  });

  it('rejects arbitrary 4-digit codes in production even if delivery is capture', () => {
    expect(
      isDevCaptureDummyOtp({
        code: '5678',
        nodeEnv: 'production',
        delivery: 'capture',
      }),
    ).toBe(false);
    expect(
      isDevCaptureDummyOtp({
        code: '1234',
        nodeEnv: 'production',
        delivery: 'capture',
      }),
    ).toBe(false);
  });

  it('rejects 4-digit codes when delivery is not capture', () => {
    expect(
      isDevCaptureDummyOtp({
        code: '1234',
        nodeEnv: 'development',
        delivery: 'unconfigured',
      }),
    ).toBe(false);
    expect(
      isDevCaptureDummyOtp({
        code: '1234',
        nodeEnv: 'development',
        delivery: 'msg91',
      }),
    ).toBe(false);
  });

  it('rejects non-4-digit input in capture development', () => {
    expect(
      isDevCaptureDummyOtp({
        code: '12',
        nodeEnv: 'development',
        delivery: 'capture',
      }),
    ).toBe(false);
    expect(
      isDevCaptureDummyOtp({
        code: '12345',
        nodeEnv: 'development',
        delivery: 'capture',
      }),
    ).toBe(false);
    expect(
      isDevCaptureDummyOtp({
        code: 'abcd',
        nodeEnv: 'development',
        delivery: 'capture',
      }),
    ).toBe(false);
  });
});
