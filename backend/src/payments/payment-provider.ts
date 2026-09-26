/**
 * Replaceable online-payment adapter.
 * beginOnlineCharge must not mark PAID. Only a verified Cashfree webhook does.
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
  paymentSessionId: string | null;
  gatewayOrderId: string | null;
  environment: 'sandbox' | 'production' | null;
};

export type OnlineRefundIntent = {
  gatewayOrderId: string;
  merchantRefundId: string;
  amount: string;
};

export type OnlineRefundResult = {
  cfRefundId: string | null;
  refundStatus: 'INITIATED' | 'PENDING' | 'SUCCESS' | 'FAILED';
  failureReason: string | null;
};

export type OnlineOrderSnapshot = {
  orderStatus: string;
  orderAmount: string;
  orderCurrency: string;
};

export interface PaymentProvider {
  beginOnlineCharge(
    input: OnlineChargeIntent,
  ): Promise<OnlineChargeBeginResult> | OnlineChargeBeginResult;
  initiateOnlineRefund?(input: OnlineRefundIntent): Promise<OnlineRefundResult>;
  retrieveOnlineOrder?(gatewayOrderId: string): Promise<OnlineOrderSnapshot>;
}
