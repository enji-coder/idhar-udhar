import { Injectable } from '@nestjs/common';
import {
  OnlineChargeBeginResult,
  OnlineChargeIntent,
  PaymentProvider,
} from './payment-provider';

/**
 * Production-safe default. Records an ONLINE intent only.
 * Never pretends a payment was captured by a gateway.
 */
@Injectable()
export class UnconfiguredPaymentProvider implements PaymentProvider {
  beginOnlineCharge(_input: OnlineChargeIntent): OnlineChargeBeginResult {
    return { providerTxnId: null, providerEventId: null };
  }
}
