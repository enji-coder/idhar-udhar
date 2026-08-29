/**
 * Replaceable online-payment adapter.
 * No production provider is chosen. ONLINE charges stay PENDING until a
 * later verified webhook/capture phase. This interface must not mark PAID.
 */
export const PAYMENT_PROVIDER = 'PAYMENT_PROVIDER';

export type OnlineChargeIntent = {
  orderId: string;
  amount: string;
  payerType: 'CUSTOMER' | 'RECEIVER';
};

export type OnlineChargeBeginResult = {
  providerTxnId: string | null;
  providerEventId: string | null;
};

export interface PaymentProvider {
  beginOnlineCharge(input: OnlineChargeIntent): OnlineChargeBeginResult;
}
