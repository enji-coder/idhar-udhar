export type CashfreeEnvironmentName = 'sandbox' | 'production';

/**
 * Host is selected only from the environment name.
 * This phase refuses to boot when the name is production.
 * The production host stays here so a later switch is configuration, not a new client.
 */
export function cashfreeApiBaseUrl(environment: CashfreeEnvironmentName): string {
  if (environment === 'sandbox') {
    return 'https://sandbox.cashfree.com/pg';
  }
  return 'https://api.cashfree.com/pg';
}

export const CASHFREE_WEBHOOK_PATH = '/v1/payments/cashfree/webhook';
