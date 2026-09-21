import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiError } from '../../common/errors/api-error';
import { ErrorCodes } from '../../common/errors/error-codes';
import { AppLogger } from '../../common/logger/app-logger';
import { AppConfig } from '../../config/configuration';
import { maskPhone } from '../phone';
import { OtpDeliveryInput, OtpDeliveryProvider } from './otp-delivery';

export const MSG91_SEND_OTP_URL = 'https://control.msg91.com/api/v5/otp';

export type Msg91HttpPost = (
  url: string,
  headers: Record<string, string>,
  body: unknown,
  timeoutMs: number,
) => Promise<{ status: number; json: unknown }>;

const SEND_FAILED_MESSAGE =
  'Could not send the verification code. Try again shortly.';

export async function defaultMsg91HttpPost(
  url: string,
  headers: Record<string, string>,
  body: unknown,
  timeoutMs: number,
): Promise<{ status: number; json: unknown }> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const text = await response.text();
    let json: unknown = null;
    if (text.length > 0) {
      try {
        json = JSON.parse(text) as unknown;
      } catch {
        json = null;
      }
    }
    return { status: response.status, json };
  } catch {
    throw new ApiError(ErrorCodes.INTERNAL_ERROR, SEND_FAILED_MESSAGE, 503);
  } finally {
    clearTimeout(timer);
  }
}

function expiryMinutes(ttlSeconds: number): number {
  return Math.max(1, Math.ceil(ttlSeconds / 60));
}

function isMsg91ErrorPayload(json: unknown): boolean {
  if (!json || typeof json !== 'object') {
    return false;
  }
  const type = (json as { type?: unknown }).type;
  return typeof type === 'string' && type.toLowerCase() === 'error';
}

/**
 * Production SMS via MSG91 SendOTP. Backend still generates, hashes,
 * expires, and verifies the code. MSG91 only delivers the SMS.
 */
@Injectable()
export class Msg91OtpDeliveryProvider implements OtpDeliveryProvider {
  readonly mode = 'msg91' as const;
  private httpPost: Msg91HttpPost = defaultMsg91HttpPost;

  constructor(
    private readonly configService: ConfigService,
    private readonly logger: AppLogger,
  ) {}

  useHttpPost(httpPost: Msg91HttpPost): void {
    this.httpPost = httpPost;
  }

  async send(input: OtpDeliveryInput): Promise<void> {
    const otp = this.configService.getOrThrow<AppConfig['otp']>('otp');
    const authKey = otp.msg91.authKey;
    const templateId = otp.msg91.templateId;
    const senderId = otp.msg91.senderId;
    if (!authKey || !templateId || !senderId) {
      this.logger.error('otp_delivery_msg91_misconfigured', {
        phone_suffix: maskPhone(input.phoneNormalized),
      });
      throw new ApiError(ErrorCodes.INTERNAL_ERROR, SEND_FAILED_MESSAGE, 503);
    }

    const minutes = expiryMinutes(otp.ttlSeconds);
    this.logger.info('otp_delivery_msg91_request', {
      phone_suffix: maskPhone(input.phoneNormalized),
      template_id: templateId,
      sender_id: senderId,
      otp_expiry_minutes: minutes,
    });

    let status: number;
    let json: unknown;
    try {
      const result = await this.httpPost(
        MSG91_SEND_OTP_URL,
        {
          authkey: authKey,
          accept: 'application/json',
          'Content-Type': 'application/json',
        },
        {
          template_id: templateId,
          sender: senderId,
          mobile: `91${input.phoneNormalized}`,
          otp: input.code,
          otp_expiry: minutes,
          var2: String(minutes),
          realTimeResponse: 1,
        },
        otp.msg91.timeoutMs,
      );
      status = result.status;
      json = result.json;
    } catch (err) {
      if (err instanceof ApiError) {
        this.logger.error('otp_delivery_msg91_unavailable', {
          phone_suffix: maskPhone(input.phoneNormalized),
        });
        throw err;
      }
      this.logger.error('otp_delivery_msg91_unavailable', {
        phone_suffix: maskPhone(input.phoneNormalized),
      });
      throw new ApiError(ErrorCodes.INTERNAL_ERROR, SEND_FAILED_MESSAGE, 503);
    }

    if (status < 200 || status >= 300 || isMsg91ErrorPayload(json)) {
      this.logger.error('otp_delivery_msg91_failed', {
        phone_suffix: maskPhone(input.phoneNormalized),
        status,
      });
      throw new ApiError(ErrorCodes.INTERNAL_ERROR, SEND_FAILED_MESSAGE, 503);
    }
  }
}
