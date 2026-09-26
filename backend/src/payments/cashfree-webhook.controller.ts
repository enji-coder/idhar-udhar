import { Controller, HttpCode, Post, RawBodyRequest, Req } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AppConfig } from '../config/configuration';
import { verifyCashfreeWebhookSignature } from './cashfree-signature';
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
  ) {}

  @Public()
  @Post('webhook')
  @HttpCode(200)
  async webhook(@Req() req: RawBodyRequest<Request>) {
    const payment = this.configService.getOrThrow<AppConfig['payment']>('payment');
    if (
      payment.provider !== 'cashfree' ||
      payment.cashfree.environment !== 'sandbox' ||
      !payment.cashfree.clientSecret
    ) {
      throw new ApiError(
        ErrorCodes.PAYMENT_PROVIDER_UNAVAILABLE,
        'Cashfree sandbox webhooks are not configured',
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
}
