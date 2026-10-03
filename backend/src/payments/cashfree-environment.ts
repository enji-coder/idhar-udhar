export type CashfreeEnvironmentName = 'sandbox' | 'production';

/**
 * PG host is selected only from the environment name.
 * Sandbox and production stay explicitly separated; never silently remap.
 */
export function cashfreeApiBaseUrl(environment: CashfreeEnvironmentName): string {
  if (environment === 'sandbox') {
    return 'https://sandbox.cashfree.com/pg';
  }
  return 'https://api.cashfree.com/pg';
}

/**
 * Payouts v2 host is selected only from the environment name.
 */
export function cashfreePayoutApiBaseUrl(
  environment: CashfreeEnvironmentName,
): string {
  if (environment === 'sandbox') {
    return 'https://sandbox.cashfree.com/payout';
  }
  return 'https://api.cashfree.com/payout';
}

export const CASHFREE_WEBHOOK_PATH = '/v1/payments/cashfree/webhook';
export const CASHFREE_PAYOUT_WEBHOOK_PATH = '/v1/payments/cashfree/payout-webhook';
