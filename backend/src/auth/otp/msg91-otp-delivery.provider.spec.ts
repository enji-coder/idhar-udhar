import { ConfigService } from '@nestjs/config';
import { ApiError } from '../../common/errors/api-error';
import { AppLogger } from '../../common/logger/app-logger';
import {
  MSG91_SEND_OTP_URL,
  Msg91HttpPost,
  Msg91OtpDeliveryProvider,
} from './msg91-otp-delivery.provider';

const AUTH_KEY = 'test-msg91-authkey-not-real';
const TEMPLATE_ID = 'test-msg91-template-id';
const SENDER_ID = 'TESTID';
const CODE = '4281';
const PHONE = '9876543210';

function providerWith(http: Msg91HttpPost): {
  instance: Msg91OtpDeliveryProvider;
  logger: { info: jest.Mock; warn: jest.Mock; error: jest.Mock };
} {
  const config = {
    getOrThrow: () => ({
      ttlSeconds: 300,
      msg91: {
        authKey: AUTH_KEY,
        templateId: TEMPLATE_ID,
        senderId: SENDER_ID,
        timeoutMs: 50,
      },
    }),
  };
  const logger = { info: jest.fn(), warn: jest.fn(), error: jest.fn() };
  const instance = new Msg91OtpDeliveryProvider(
    config as unknown as ConfigService,
    logger as unknown as AppLogger,
  );
  instance.useHttpPost(http);
  return { instance, logger };
}

function loggedText(logger: {
  info: jest.Mock;
  warn: jest.Mock;
  error: jest.Mock;
}): string {
  return JSON.stringify([
    ...logger.info.mock.calls,
    ...logger.warn.mock.calls,
    ...logger.error.mock.calls,
  ]);
}

describe('Msg91OtpDeliveryProvider', () => {
  it('posts SendOTP with template, sender, OTP, and validity minutes', async () => {
    const seen: Array<{
      url: string;
      headers: Record<string, string>;
      body: unknown;
    }> = [];
    const { instance, logger } = providerWith(async (url, headers, body) => {
      seen.push({ url, headers, body });
      return { status: 200, json: { type: 'success' } };
    });

    await instance.send({ phoneNormalized: PHONE, code: CODE });

    expect(seen).toHaveLength(1);
    expect(seen[0].url).toBe(MSG91_SEND_OTP_URL);
    expect(seen[0].headers.authkey).toBe(AUTH_KEY);
    expect(seen[0].body).toEqual({
      template_id: TEMPLATE_ID,
      sender: SENDER_ID,
      mobile: `91${PHONE}`,
      otp: CODE,
      otp_expiry: 5,
      var2: '5',
      realTimeResponse: 1,
    });
    const logs = loggedText(logger);
    expect(logs).not.toContain(CODE);
    expect(logs).not.toContain(AUTH_KEY);
    expect(logs).toContain(TEMPLATE_ID);
    expect(logs).toContain(SENDER_ID);
  });

  it('fails without pretending SMS was sent when MSG91 returns an error', async () => {
    const { instance, logger } = providerWith(async () => ({
      status: 200,
      json: { type: 'error', message: `otp ${CODE} failed` },
    }));

    await expect(
      instance.send({ phoneNormalized: PHONE, code: CODE }),
    ).rejects.toMatchObject<Partial<ApiError>>({
      code: 'INTERNAL_ERROR',
      status: 503,
    });
    const logs = loggedText(logger);
    expect(logs).not.toContain(CODE);
    expect(logs).not.toContain(AUTH_KEY);
  });

  it('fails clearly on HTTP / network errors', async () => {
    const { instance, logger } = providerWith(async () => ({
      status: 503,
      json: { type: 'error' },
    }));

    await expect(
      instance.send({ phoneNormalized: PHONE, code: CODE }),
    ).rejects.toBeInstanceOf(ApiError);

    const unavailable = providerWith(async () => {
      throw new Error('socket hang up');
    });
    await expect(
      unavailable.instance.send({ phoneNormalized: PHONE, code: CODE }),
    ).rejects.toMatchObject({ code: 'INTERNAL_ERROR', status: 503 });
    expect(loggedText(logger)).not.toContain(CODE);
    expect(loggedText(unavailable.logger)).not.toContain(AUTH_KEY);
  });
});
