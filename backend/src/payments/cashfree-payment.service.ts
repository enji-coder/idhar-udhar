import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AppLogger } from '../common/logger/app-logger';
import { PostgresService } from '../database/postgres.service';
import { AppConfig } from '../config/configuration';
import { gatewayAmountToInr } from './cashfree-amount';
import { cashfreeApiBaseUrl } from './cashfree-environment';
import { newGatewayOrderId } from './cashfree-webhook.parse';
import {
  OnlineChargeBeginResult,
  OnlineChargeIntent,
  OnlineOrderSnapshot,
  OnlineRefundIntent,
  OnlineRefundResult,
  PaymentProvider,
} from './payment-provider';

type CashfreeSettings = AppConfig['payment']['cashfree'];

export type CashfreeHttp = (
  url: string,
  init: {
    method: 'GET' | 'POST';
    headers: Record<string, string>;
    body?: string;
    timeoutMs: number;
  },
) => Promise<{ status: number; json: unknown }>;

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

export async function defaultCashfreeHttp(
  url: string,
  init: {
    method: 'GET' | 'POST';
    headers: Record<string, string>;
    body?: string;
    timeoutMs: number;
  },
): Promise<{ status: number; json: unknown }> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), init.timeoutMs);
  try {
    const response = await fetch(url, {
      method: init.method,
      headers: init.headers,
      body: init.body,
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
    throw new ApiError(
      ErrorCodes.PAYMENT_GATEWAY_REJECTED,
      'Cashfree sandbox did not respond',
      503,
    );
  } finally {
    clearTimeout(timer);
  }
}

function mapRefundStatus(raw: unknown): OnlineRefundResult['refundStatus'] {
  const status = typeof raw === 'string' ? raw.toUpperCase() : '';
  if (status === 'SUCCESS') {
    return 'SUCCESS';
  }
  if (status === 'PENDING' || status === 'ONHOLD') {
    return 'PENDING';
  }
  if (status === 'CANCELLED' || status === 'FAILED') {
    return 'FAILED';
  }
  return 'INITIATED';
}

@Injectable()
export class CashfreePaymentService implements PaymentProvider {
  private http: CashfreeHttp = defaultCashfreeHttp;

  constructor(
    private readonly configService: ConfigService,
    private readonly postgres: PostgresService,
    private readonly logger: AppLogger,
  ) {}

  useHttp(http: CashfreeHttp): void {
    this.http = http;
  }

  private settings(): CashfreeSettings {
    return this.configService.getOrThrow<AppConfig['payment']>('payment').cashfree;
  }

  private assertSandbox(settings: CashfreeSettings): void {
    if (settings.environment !== 'sandbox') {
      throw new ApiError(
        ErrorCodes.PAYMENT_PROVIDER_UNAVAILABLE,
        'Cashfree production is not enabled',
        503,
      );
    }
    if (!settings.clientId || !settings.clientSecret) {
      throw new ApiError(
        ErrorCodes.PAYMENT_PROVIDER_UNAVAILABLE,
        'Cashfree sandbox credentials are not configured',
        503,
      );
    }
  }

  private headers(settings: CashfreeSettings, idempotencyKey?: string): Record<string, string> {
    const headers: Record<string, string> = {
      'content-type': 'application/json',
      'x-api-version': settings.apiVersion,
      'x-client-id': settings.clientId ?? '',
      'x-client-secret': settings.clientSecret ?? '',
    };
    if (idempotencyKey) {
      headers['x-idempotency-key'] = idempotencyKey;
    }
    return headers;
  }

  async beginOnlineCharge(input: OnlineChargeIntent): Promise<OnlineChargeBeginResult> {
    const settings = this.settings();
    this.assertSandbox(settings);
    const customer = await this.postgres.query<{
      customer_profile_id: string;
      phone_normalized: string;
    }>(
      `
      SELECT c.customer_profile_id, i.phone_normalized
      FROM orders o
      JOIN customer_profiles c ON c.customer_profile_id = o.customer_profile_id
      JOIN identities i ON i.identity_id = c.identity_id
      WHERE o.order_id = $1
      `,
      [input.orderId],
    );
    const row = customer.rows[0];
    if (!row?.phone_normalized || !/^\d{10}$/.test(row.phone_normalized)) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Customer phone is required before an online payment can start',
        409,
      );
    }
    const gatewayOrderId = newGatewayOrderId();
    const response = await this.http(`${settings.apiBaseUrl}/orders`, {
      method: 'POST',
      headers: this.headers(settings, gatewayOrderId),
      body: JSON.stringify({
        order_id: gatewayOrderId,
        order_amount: Number(input.amount),
        order_currency: 'INR',
        customer_details: {
          customer_id: row.customer_profile_id,
          customer_phone: row.phone_normalized,
        },
        order_tags: {
          internal_order_id: input.orderId,
        },
      }),
      timeoutMs: settings.timeoutMs,
    });
    const body = asRecord(response.json);
    const sessionId =
      typeof body?.payment_session_id === 'string' ? body.payment_session_id : '';
    const cfOrderId =
      body?.cf_order_id === undefined || body.cf_order_id === null
        ? ''
        : String(body.cf_order_id);
    const returnedOrderId = typeof body?.order_id === 'string' ? body.order_id : '';
    const returnedAmount = gatewayAmountToInr(body?.order_amount);
    const returnedCurrency =
      typeof body?.order_currency === 'string' ? body.order_currency.toUpperCase() : '';
    if (
      response.status !== 200 ||
      !sessionId ||
      !cfOrderId ||
      returnedOrderId !== gatewayOrderId ||
      returnedAmount !== input.amount ||
      returnedCurrency !== 'INR'
    ) {
      this.logger.warn('cashfree_order_rejected', {
        order_id: input.orderId,
        gateway_order_id: gatewayOrderId,
        http_status: response.status,
      });
      throw new ApiError(
        ErrorCodes.PAYMENT_GATEWAY_REJECTED,
        'Cashfree sandbox did not create a payment order',
        502,
      );
    }
    this.logger.info('cashfree_order_created', {
      order_id: input.orderId,
      gateway_order_id: gatewayOrderId,
      cf_order_id: cfOrderId,
    });
    return {
      providerTxnId: cfOrderId,
      providerEventId: null,
      paymentSessionId: sessionId,
      gatewayOrderId,
      environment: 'sandbox',
    };
  }

  async retrieveOnlineOrder(gatewayOrderId: string): Promise<OnlineOrderSnapshot> {
    const settings = this.settings();
    this.assertSandbox(settings);
    const response = await this.http(
      `${settings.apiBaseUrl}/orders/${encodeURIComponent(gatewayOrderId)}`,
      {
        method: 'GET',
        headers: this.headers(settings),
        timeoutMs: settings.timeoutMs,
      },
    );
    const body = asRecord(response.json);
    const orderAmount = gatewayAmountToInr(body?.order_amount);
    const orderCurrency =
      typeof body?.order_currency === 'string' ? body.order_currency.toUpperCase() : '';
    const orderStatus = typeof body?.order_status === 'string' ? body.order_status : '';
    if (response.status !== 200 || !orderAmount || !orderCurrency || !orderStatus) {
      this.logger.warn('cashfree_order_fetch_failed', {
        gateway_order_id: gatewayOrderId,
        http_status: response.status,
      });
      throw new ApiError(
        ErrorCodes.PAYMENT_GATEWAY_REJECTED,
        'Cashfree sandbox did not return the order',
        502,
      );
    }
    return { orderStatus, orderAmount, orderCurrency };
  }

  async initiateOnlineRefund(input: OnlineRefundIntent): Promise<OnlineRefundResult> {
    const settings = this.settings();
    this.assertSandbox(settings);
    const url = `${settings.apiBaseUrl}/orders/${encodeURIComponent(input.gatewayOrderId)}/refunds`;
    const response = await this.http(url, {
      method: 'POST',
      headers: this.headers(settings, input.merchantRefundId),
      body: JSON.stringify({
        refund_amount: Number(input.amount),
        refund_id: input.merchantRefundId,
        refund_note: 'Idhar Udhar refund',
      }),
      timeoutMs: settings.timeoutMs,
    });
    if (response.status === 409) {
      return this.fetchRefund(input);
    }
    return this.readRefund(response.status, response.json, input);
  }

  private async fetchRefund(input: OnlineRefundIntent): Promise<OnlineRefundResult> {
    const settings = this.settings();
    const response = await this.http(
      `${settings.apiBaseUrl}/orders/${encodeURIComponent(input.gatewayOrderId)}/refunds/${encodeURIComponent(input.merchantRefundId)}`,
      {
        method: 'GET',
        headers: this.headers(settings),
        timeoutMs: settings.timeoutMs,
      },
    );
    return this.readRefund(response.status, response.json, input);
  }

  private readRefund(
    status: number,
    json: unknown,
    input: OnlineRefundIntent,
  ): OnlineRefundResult {
    const body = asRecord(json);
    const amount = gatewayAmountToInr(body?.refund_amount);
    const refundStatus = mapRefundStatus(body?.refund_status);
    const cfRefundId =
      body?.cf_refund_id === undefined || body.cf_refund_id === null
        ? null
        : String(body.cf_refund_id);
    if (status !== 200 || amount !== input.amount) {
      this.logger.warn('cashfree_refund_rejected', {
        gateway_order_id: input.gatewayOrderId,
        merchant_refund_id: input.merchantRefundId,
        http_status: status,
      });
      throw new ApiError(
        ErrorCodes.PAYMENT_GATEWAY_REJECTED,
        'Cashfree sandbox did not accept the refund',
        502,
      );
    }
    this.logger.info('cashfree_refund_requested', {
      gateway_order_id: input.gatewayOrderId,
      merchant_refund_id: input.merchantRefundId,
      refund_status: refundStatus,
    });
    return {
      cfRefundId,
      refundStatus,
      failureReason:
        refundStatus === 'FAILED' && typeof body?.status_description === 'string'
          ? body.status_description.slice(0, 300)
          : null,
    };
  }
}

export function resolvedCashfreeBaseUrl(environment: 'sandbox' | 'production'): string {
  return cashfreeApiBaseUrl(environment);
}
