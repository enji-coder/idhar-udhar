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
      'Cashfree did not respond',
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

  private assertConfigured(settings: CashfreeSettings): void {
    if (settings.environment !== 'sandbox' && settings.environment !== 'production') {
      throw new ApiError(
        ErrorCodes.PAYMENT_PROVIDER_UNAVAILABLE,
        'Cashfree environment is not configured',
        503,
      );
    }
    if (!settings.clientId || !settings.clientSecret) {
      throw new ApiError(
        ErrorCodes.PAYMENT_PROVIDER_UNAVAILABLE,
        `Cashfree ${settings.environment} credentials are not configured`,
        503,
      );
    }
  }

  private pgHeaders(settings: CashfreeSettings, idempotencyKey?: string): Record<string, string> {
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

  private payoutHeaders(
    settings: CashfreeSettings,
    idempotencyKey?: string,
  ): Record<string, string> {
    const headers: Record<string, string> = {
      'content-type': 'application/json',
      'x-api-version': settings.payoutApiVersion,
      'x-client-id': settings.clientId ?? '',
      'x-client-secret': settings.clientSecret ?? '',
    };
    if (idempotencyKey) {
      headers['x-request-id'] = idempotencyKey;
    }
    return headers;
  }

  async beginOnlineCharge(input: OnlineChargeIntent): Promise<OnlineChargeBeginResult> {
    const settings = this.settings();
    this.assertConfigured(settings);
    const walletTopUp =
      input.purpose === 'WALLET_TOPUP' || input.payerType === 'RIDER';
    let customerId: string;
    let customerPhone: string;
    let orderTags: Record<string, string>;
    let logOrderId: string | null;
    if (walletTopUp) {
      if (!input.riderProfileId) {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Rider profile is required for wallet top-up',
          400,
        );
      }
      const rider = await this.postgres.query<{
        rider_profile_id: string;
        phone_normalized: string;
      }>(
        `
        SELECT r.rider_profile_id, i.phone_normalized
        FROM rider_profiles r
        JOIN identities i ON i.identity_id = r.identity_id
        WHERE r.rider_profile_id = $1
        `,
        [input.riderProfileId],
      );
      const row = rider.rows[0];
      if (!row?.phone_normalized || !/^\d{10}$/.test(row.phone_normalized)) {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Rider phone is required before an online payment can start',
          409,
        );
      }
      customerId = row.rider_profile_id;
      customerPhone = row.phone_normalized;
      orderTags = {
        wallet_topup: 'true',
        rider_profile_id: input.riderProfileId,
      };
      logOrderId = input.riderProfileId;
    } else {
      if (!input.orderId) {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Order is required for booking payments',
          400,
        );
      }
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
      customerId = row.customer_profile_id;
      customerPhone = row.phone_normalized;
      orderTags = { internal_order_id: input.orderId };
      logOrderId = input.orderId;
    }
    const gatewayOrderId = newGatewayOrderId();
    const response = await this.http(`${settings.apiBaseUrl}/orders`, {
      method: 'POST',
      headers: this.pgHeaders(settings, gatewayOrderId),
      body: JSON.stringify({
        order_id: gatewayOrderId,
        order_amount: Number(input.amount),
        order_currency: 'INR',
        customer_details: {
          customer_id: customerId,
          customer_phone: customerPhone,
        },
        order_tags: orderTags,
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
        order_id: logOrderId,
        gateway_order_id: gatewayOrderId,
        http_status: response.status,
      });
      throw new ApiError(
        ErrorCodes.PAYMENT_GATEWAY_REJECTED,
        'Cashfree did not create a payment order',
        502,
      );
    }
    this.logger.info('cashfree_order_created', {
      order_id: logOrderId,
      gateway_order_id: gatewayOrderId,
      cf_order_id: cfOrderId,
      environment: settings.environment,
    });
    return {
      providerTxnId: cfOrderId,
      providerEventId: null,
      paymentSessionId: sessionId,
      gatewayOrderId,
      environment: settings.environment,
    };
  }

  async retrieveOnlineOrder(gatewayOrderId: string): Promise<OnlineOrderSnapshot> {
    const settings = this.settings();
    this.assertConfigured(settings);
    const response = await this.http(
      `${settings.apiBaseUrl}/orders/${encodeURIComponent(gatewayOrderId)}`,
      {
        method: 'GET',
        headers: this.pgHeaders(settings),
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
        'Cashfree did not return the order',
        502,
      );
    }
    return { orderStatus, orderAmount, orderCurrency };
  }

  async initiateOnlineRefund(input: OnlineRefundIntent): Promise<OnlineRefundResult> {
    const settings = this.settings();
    this.assertConfigured(settings);
    const url = `${settings.apiBaseUrl}/orders/${encodeURIComponent(input.gatewayOrderId)}/refunds`;
    const response = await this.http(url, {
      method: 'POST',
      headers: this.pgHeaders(settings, input.merchantRefundId),
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

  /**
   * Initiates a Cashfree Payouts v2 transfer.
   * Caller must persist merchantTransferId before invoking so timeouts can reconcile.
   */
  async initiatePayoutTransfer(input: {
    merchantTransferId: string;
    amount: string;
    payoutMethod: 'UPI' | 'BANK';
    beneficiaryId: string;
    vpa?: string | null;
    bankAccountNumber?: string | null;
    bankIfsc?: string | null;
  }): Promise<{
    outcome: 'accepted' | 'rejected';
    providerTransferId: string | null;
    providerStatus: string | null;
    failureReason: string | null;
  }> {
    const settings = this.settings();
    this.assertConfigured(settings);
    const transferMode = input.payoutMethod === 'UPI' ? 'upi' : 'banktransfer';
    const instrument =
      input.payoutMethod === 'UPI'
        ? { vpa: input.vpa }
        : {
            bank_account_number: input.bankAccountNumber,
            bank_ifsc: input.bankIfsc,
          };
    const response = await this.http(`${settings.payoutApiBaseUrl}/transfers`, {
      method: 'POST',
      headers: this.payoutHeaders(settings, input.merchantTransferId),
      body: JSON.stringify({
        transfer_id: input.merchantTransferId,
        transfer_amount: Number(input.amount),
        transfer_currency: 'INR',
        transfer_mode: transferMode,
        beneficiary_details: {
          beneficiary_id: input.beneficiaryId,
          beneficiary_instrument_details: instrument,
        },
      }),
      timeoutMs: settings.timeoutMs,
    });
    return this.readPayoutTransferResponse(response.status, response.json, input.merchantTransferId);
  }

  async retrievePayoutTransfer(merchantTransferId: string): Promise<{
    outcome: 'success' | 'failed' | 'pending' | 'reversed' | 'unknown';
    providerTransferId: string | null;
    providerStatus: string | null;
    failureReason: string | null;
  }> {
    const settings = this.settings();
    this.assertConfigured(settings);
    const response = await this.http(
      `${settings.payoutApiBaseUrl}/transfers?transfer_id=${encodeURIComponent(merchantTransferId)}`,
      {
        method: 'GET',
        headers: this.payoutHeaders(settings),
        timeoutMs: settings.timeoutMs,
      },
    );
    if (response.status === 404) {
      return {
        outcome: 'unknown',
        providerTransferId: null,
        providerStatus: null,
        failureReason: 'Transfer was not found at Cashfree',
      };
    }
    const mapped = this.readPayoutTransferResponse(
      response.status,
      response.json,
      merchantTransferId,
    );
    if (mapped.outcome === 'rejected') {
      return {
        outcome: 'failed',
        providerTransferId: mapped.providerTransferId,
        providerStatus: mapped.providerStatus,
        failureReason: mapped.failureReason,
      };
    }
    return this.mapPayoutProviderStatus(mapped.providerStatus, mapped.providerTransferId, mapped.failureReason);
  }

  private mapPayoutProviderStatus(
    providerStatus: string | null,
    providerTransferId: string | null,
    failureReason: string | null,
  ): {
    outcome: 'success' | 'failed' | 'pending' | 'reversed' | 'unknown';
    providerTransferId: string | null;
    providerStatus: string | null;
    failureReason: string | null;
  } {
    const status = (providerStatus ?? '').toUpperCase();
    if (status === 'SUCCESS' || status === 'COMPLETED') {
      return {
        outcome: 'success',
        providerTransferId,
        providerStatus,
        failureReason: null,
      };
    }
    if (status === 'FAILED' || status === 'REJECTED' || status === 'FAILED_AT_BANK') {
      return {
        outcome: 'failed',
        providerTransferId,
        providerStatus,
        failureReason,
      };
    }
    if (status === 'REVERSED') {
      return {
        outcome: 'reversed',
        providerTransferId,
        providerStatus,
        failureReason,
      };
    }
    if (status === 'PENDING' || status === 'RECEIVED' || status === 'APPROVAL_PENDING') {
      return {
        outcome: 'pending',
        providerTransferId,
        providerStatus,
        failureReason: null,
      };
    }
    return {
      outcome: 'unknown',
      providerTransferId,
      providerStatus,
      failureReason: failureReason ?? 'Unrecognized payout status',
    };
  }

  private readPayoutTransferResponse(
    status: number,
    json: unknown,
    merchantTransferId: string,
  ): {
    outcome: 'accepted' | 'rejected';
    providerTransferId: string | null;
    providerStatus: string | null;
    failureReason: string | null;
  } {
    const body = asRecord(json);
    const data = asRecord(body?.data) ?? body;
    const providerStatus =
      typeof data?.status === 'string'
        ? data.status.toUpperCase()
        : typeof body?.status === 'string'
          ? body.status.toUpperCase()
          : null;
    const providerTransferId =
      data?.cf_transfer_id === undefined || data?.cf_transfer_id === null
        ? null
        : String(data.cf_transfer_id);
    const failureReasonRaw =
      typeof data?.status_description === 'string'
        ? data.status_description
        : typeof body?.message === 'string'
          ? body.message
          : null;
    const failureReason = failureReasonRaw ? failureReasonRaw.slice(0, 300) : null;
    if (status === 200 || status === 201 || status === 409) {
      this.logger.info('cashfree_payout_transfer_accepted', {
        merchant_transfer_id: merchantTransferId,
        provider_transfer_id: providerTransferId,
        provider_status: providerStatus,
        http_status: status,
      });
      return {
        outcome: 'accepted',
        providerTransferId,
        providerStatus,
        failureReason,
      };
    }
    this.logger.warn('cashfree_payout_transfer_rejected', {
      merchant_transfer_id: merchantTransferId,
      http_status: status,
      provider_status: providerStatus,
    });
    return {
      outcome: 'rejected',
      providerTransferId,
      providerStatus,
      failureReason: failureReason ?? 'Cashfree rejected the payout transfer',
    };
  }

  private async fetchRefund(input: OnlineRefundIntent): Promise<OnlineRefundResult> {
    const settings = this.settings();
    const response = await this.http(
      `${settings.apiBaseUrl}/orders/${encodeURIComponent(input.gatewayOrderId)}/refunds/${encodeURIComponent(input.merchantRefundId)}`,
      {
        method: 'GET',
        headers: this.pgHeaders(settings),
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
        'Cashfree did not accept the refund',
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
