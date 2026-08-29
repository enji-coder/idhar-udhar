import { formatInr } from '../fare/money';

export type AggregatePaymentStatus = 'UNPAID' | 'PARTIALLY_PAID' | 'PAID';

export type PayerType = 'CUSTOMER' | 'RECEIVER';
export type WhoPays = 'CUSTOMER' | 'RECEIVER' | 'SPLIT';
export type PaymentMethod = 'ONLINE' | 'CASH';
export type PaymentDirection = 'CHARGE' | 'REFUND';
export type TransactionStatus = 'PENDING' | 'PAID' | 'FAILED' | 'REFUNDED';

/**
 * Derived aggregate status. Not a payment_transactions.transaction_status.
 * PAID only when paid equals owed after NUMERIC formatting. Overpay is not PAID.
 */
export function deriveAggregateStatus(
  paid: string,
  owed: string,
): AggregatePaymentStatus {
  const p = formatInr(paid);
  const o = formatInr(owed);
  if (o === '0.00') {
    return 'PAID';
  }
  if (p === '0.00') {
    return 'UNPAID';
  }
  if (p === o) {
    return 'PAID';
  }
  return 'PARTIALLY_PAID';
}
