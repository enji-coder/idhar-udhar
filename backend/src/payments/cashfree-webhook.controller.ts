import { Controller, HttpCode, Post, RawBodyRequest, Req } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AppLogger } from '../common/logger/app-logger';
import { AppConfig } from '../config/configuration';
import {
  SignatureCheck,
  verifyCashfreeWebhookSignature,
} from './cashfree-signature';
import { cashfreeEventId, parseCashfreeWebhook } from './cashfree-webhook.parse';
import {
  CashfreeWebhookService,
  webhookRejected,
} from './cashfree-webhook.service';

function headerValue(value: string | string[] | undefined): string {
  if (Array.isArray(value)) {
    return value[0] ?? '';
  }
  return value ?? '';
}

@Controller('payments/cashfree')
export class CashfreeWebhookController {
  constructor(
    private readonly configService: ConfigService,
    private readonly webhooks: CashfreeWebhookService,
    private readonly logger: AppLogger,
  ) {}

  @Public()
  @Post('webhook')
  @HttpCode(200)
  async webhook(@Req() req: RawBodyRequest<Request>) {
    const payment = this.configService.getOrThrow<AppConfig['payment']>('payment');
    if (
      payment.provider !== 'cashfree' ||
      (payment.cashfree.environment !== 'sandbox' &&
        payment.cashfree.environment !== 'production') ||
      !payment.cashfree.clientSecret
    ) {
      throw new ApiError(
        ErrorCodes.PAYMENT_PROVIDER_UNAVAILABLE,
        'Cashfree webhooks are not configured',
        503,
      );
    }
    const raw = req.rawBody?.toString('utf8');
    if (!raw) {
      throw new ApiError(
        ErrorCodes.PAYMENT_WEBHOOK_INVALID,
        'Cashfree webhook body was not available for signature verification',
        400,
      );
    }
    const check = verifyCashfreeWebhookSignature({
      secret: payment.cashfree.clientSecret,
      rawBody: raw,
      timestamp: headerValue(req.headers['x-webhook-timestamp']),
      signature: headerValue(req.headers['x-webhook-signature']),
    });
    if (!check.ok) {
      this.logStagingRejection(check);
      throw webhookRejected();
    }
    let parsedBody: unknown;
    try {
      parsedBody = JSON.parse(raw) as unknown;
    } catch {
      throw new ApiError(
        ErrorCodes.PAYMENT_WEBHOOK_INVALID,
        'Cashfree webhook body was not valid JSON',
        400,
      );
    }
    const result = await this.webhooks.apply({
      eventId: cashfreeEventId(raw),
      rawBody: raw,
      parsed: parseCashfreeWebhook(parsedBody),
    });
    return { received: true, result };
  }

  /**
   * Staging diagnosis only. The timestamp, signature, raw body, headers, and
   * secret stay out of the log. Acceptance is unchanged.
   */
  private logStagingRejection(check: Exclude<SignatureCheck, { ok: true }>): void {
    const tier = (process.env.IU_DEPLOYMENT_TIER ?? '').trim().toLowerCase();
    if (tier !== 'staging') {
      return;
    }
    const fields: Record<string, string | number> = { reason: check.reason };
    const diagnostic = check.timestampDiagnostic;
    if (diagnostic) {
      fields.timestamp_bucket = diagnostic.timestamp_bucket;
      if (
        typeof diagnostic.skew_seconds === 'number' &&
        Number.isSafeInteger(diagnostic.skew_seconds)
      ) {
        fields.skew_seconds = diagnostic.skew_seconds;
      }
      if (
        diagnostic.timestamp_digits === '10_digit' ||
        diagnostic.timestamp_digits === '13_digit' ||
        diagnostic.timestamp_digits === 'other_digit_length'
      ) {
        fields.timestamp_digits = diagnostic.timestamp_digits;
      }
    }
    this.logger.warn('cashfree_webhook_rejected', fields);
  }
}
