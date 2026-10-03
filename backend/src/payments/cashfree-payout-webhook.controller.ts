import {
  Controller,
  HttpCode,
  Inject,
  Post,
  RawBodyRequest,
  Req,
  forwardRef,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AppConfig } from '../config/configuration';
import { WalletCodService } from '../wallet-cod/wallet-cod.service';
import { verifyCashfreeWebhookSignature } from './cashfree-signature';
import {
  cashfreePayoutEventId,
  parseCashfreePayoutWebhook,
} from './cashfree-payout-webhook.parse';
import { webhookRejected } from './cashfree-webhook.service';

function headerValue(value: string | string[] | undefined): string {
  if (Array.isArray(value)) {
    return value[0] ?? '';
  }
  return value ?? '';
}

@Controller('payments/cashfree')
export class CashfreePayoutWebhookController {
  constructor(
    private readonly configService: ConfigService,
    @Inject(forwardRef(() => WalletCodService))
    private readonly walletCod: WalletCodService,
  ) {}

  @Public()
  @Post('payout-webhook')
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
        'Cashfree payout webhooks are not configured',
        503,
      );
    }
    const raw = req.rawBody?.toString('utf8');
    if (!raw) {
      throw new ApiError(
        ErrorCodes.PAYMENT_WEBHOOK_INVALID,
        'Cashfree payout webhook body was not available for signature verification',
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
        'Cashfree payout webhook body was not valid JSON',
        400,
      );
    }
    const parsed = parseCashfreePayoutWebhook(parsedBody);
    if (parsed.kind === 'ignored') {
      return {
        received: true,
        result: 'ignored',
        event_id: cashfreePayoutEventId(raw),
      };
    }
    const applied = await this.walletCod.applyPayoutWebhookByMerchantTransferId({
      merchantTransferId: parsed.merchantTransferId,
      providerTransferId: parsed.providerTransferId,
      providerStatus: parsed.providerStatus,
      failureReason: parsed.failureReason,
    });
    return {
      received: true,
      result: applied.result,
      status: applied.status,
      event_id: cashfreePayoutEventId(raw),
    };
  }
}
