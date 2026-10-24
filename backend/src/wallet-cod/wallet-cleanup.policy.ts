import { formatInr } from '../fare/money';

export type CleanupKind = 'RIDER_WALLET' | 'RIDER_COD' | 'CUSTOMER_WALLET';

const ORDER_TIED_WALLET_TYPES = new Set([
  'EARNING',
  'CANCELLATION_SHARE',
  'RESEND_EARNING',
  'RECHARGE',
]);

const PROTECTED_COD_SOURCES = new Set([
  'CASH_COMPANY_SHARE',
  'RECHARGE_SETTLEMENT',
  'DIGITAL_EARNING_SETTLEMENT',
  'CANCELLATION_SHARE_SETTLEMENT',
]);

export type CleanupAssessment = {
  allowed: boolean;
  reasons: string[];
  /** Signed cents applied to the materialized balance. Credit reversal is negative. */
  balance_delta_cents: number;
  projected_balance: string;
};

function cents(raw: string): number {
  const formatted = formatInr(raw);
  const negative = formatted.startsWith('-');
  const [whole, frac] = formatted.replace('-', '').split('.');
  const value = Number(whole) * 100 + Number(frac);
  return negative ? -value : value;
}

export function centsToInr(value: number): string {
  const negative = value < 0;
  const abs = Math.abs(value);
  const whole = Math.floor(abs / 100);
  const frac = String(abs % 100).padStart(2, '0');
  return formatInr(negative ? `-${whole}.${frac}` : `${whole}.${frac}`);
}

/** Cents left on the account after posting the opposite of this entry. */
function projectOpposite(
  direction: 'CREDIT' | 'DEBIT' | 'INCREASE' | 'DECREASE',
  amount: string,
  balance: string,
): number {
  const magnitude = cents(amount);
  const delta = direction === 'CREDIT' || direction === 'INCREASE' ? -magnitude : magnitude;
  return cents(balance) + delta;
}

function refused(reasons: string[], balance: string): CleanupAssessment {
  return {
    allowed: false,
    reasons,
    balance_delta_cents: 0,
    projected_balance: formatInr(balance),
  };
}

/**
 * A row is eligible only when an administrator has selected it and it is not
 * settled financial history. Amount, age, and description are not evidence.
 */
export function assessRiderWalletCleanup(input: {
  entryType: string;
  direction: 'CREDIT' | 'DEBIT';
  amount: string;
  balance: string;
  relatedOrderId: string | null;
  relatedPaymentTransactionId: string | null;
  relatedCodLedgerId: string | null;
  pairedCodSource: string | null;
  pairedCod?: {
    direction: 'INCREASE' | 'DECREASE';
    amount: string;
    due: string;
  } | null;
  alreadyReversed: boolean;
}): CleanupAssessment {
  const reasons: string[] = [];
  if (input.alreadyReversed) {
    reasons.push('This entry already has a reversal.');
  }
  if (input.entryType === 'REVERSAL') {
    reasons.push('A reversal is an accounting correction and is not removed.');
  }
  if (input.relatedPaymentTransactionId) {
    reasons.push('This entry is linked to a payment transaction and is retained.');
  }
  if (input.entryType === 'PAYOUT' || input.entryType === 'COD_SETTLEMENT') {
    reasons.push('Payout and COD settlement entries are retained.');
  }
  if (input.relatedOrderId && (ORDER_TIED_WALLET_TYPES.has(input.entryType) || input.entryType === 'ADJUSTMENT')) {
    reasons.push('This entry is tied to an order and is retained.');
  }
  if (input.relatedCodLedgerId) {
    if (input.pairedCodSource == null) {
      reasons.push('The paired COD ledger row could not be found.');
    } else if (PROTECTED_COD_SOURCES.has(input.pairedCodSource) || input.pairedCodSource === 'REVERSAL') {
      reasons.push('The paired COD ledger row is settled history and is retained.');
    } else if (input.pairedCodSource === 'ADMIN_ADJUSTMENT' && input.pairedCod == null) {
      reasons.push('The paired COD balance could not be confirmed.');
    }
  }
  if (reasons.length > 0) {
    return refused(reasons, input.balance);
  }
  if (input.pairedCod) {
    const pairedDue = projectOpposite(
      input.pairedCod.direction,
      input.pairedCod.amount,
      input.pairedCod.due,
    );
    if (pairedDue < 0) {
      return refused(
        ['The reversal would make COD due negative, which this ledger does not allow.'],
        input.balance,
      );
    }
  }
  const amount = cents(input.amount);
  const delta = input.direction === 'CREDIT' ? -amount : amount;
  const projected = cents(input.balance) + delta;
  if (projected < 0) {
    return refused(
      ['The reversal would make the wallet balance negative, which this ledger does not allow.'],
      input.balance,
    );
  }
  return {
    allowed: true,
    reasons: [],
    balance_delta_cents: delta,
    projected_balance: centsToInr(projected),
  };
}

export function assessCodCleanup(input: {
  source: string;
  direction: 'INCREASE' | 'DECREASE';
  amount: string;
  codDue: string;
  relatedOrderId: string | null;
  relatedWalletEntryType: string | null;
  pairedWallet?: {
    direction: 'CREDIT' | 'DEBIT';
    amount: string;
    balance: string;
  } | null;
  alreadyReversed: boolean;
}): CleanupAssessment {
  const reasons: string[] = [];
  if (input.alreadyReversed) {
    reasons.push('This COD entry already has a reversal.');
  }
  if (input.source === 'REVERSAL' || PROTECTED_COD_SOURCES.has(input.source)) {
    reasons.push('Settled COD collections and settlements are retained.');
  }
  if (input.source === 'ADMIN_ADJUSTMENT' && input.relatedOrderId) {
    reasons.push('This COD adjustment is tied to an order and is retained.');
  }
  if (input.relatedWalletEntryType && input.relatedWalletEntryType !== 'ADJUSTMENT') {
    reasons.push('The paired wallet entry is settled history and is retained.');
  } else if (input.relatedWalletEntryType === 'ADJUSTMENT' && input.pairedWallet == null) {
    reasons.push('The paired wallet balance could not be confirmed.');
  }
  if (input.source !== 'ADMIN_ADJUSTMENT' && reasons.length === 0) {
    reasons.push('Only an admin adjustment can be cleaned up from the COD ledger.');
  }
  if (reasons.length > 0) {
    return refused(reasons, input.codDue);
  }
  if (input.pairedWallet) {
    const pairedBalance = projectOpposite(
      input.pairedWallet.direction,
      input.pairedWallet.amount,
      input.pairedWallet.balance,
    );
    if (pairedBalance < 0) {
      return refused(
        ['The reversal would make the wallet balance negative, which this ledger does not allow.'],
        input.codDue,
      );
    }
  }
  const amount = cents(input.amount);
  const delta = input.direction === 'INCREASE' ? -amount : amount;
  const projected = cents(input.codDue) + delta;
  if (projected < 0) {
    return refused(
      ['The reversal would make COD due negative, which this ledger does not allow.'],
      input.codDue,
    );
  }
  return {
    allowed: true,
    reasons: [],
    balance_delta_cents: delta,
    projected_balance: centsToInr(projected),
  };
}

export function assessCustomerWalletCleanup(input: {
  entryType: string;
  direction: 'CREDIT' | 'DEBIT';
  amount: string;
  balance: string;
  relatedOrderId: string | null;
  alreadyReversed: boolean;
}): CleanupAssessment {
  const reasons: string[] = [];
  if (input.alreadyReversed) {
    reasons.push('This entry already has a reversal.');
  }
  if (input.entryType === 'REVERSAL') {
    reasons.push('A reversal is an accounting correction and is not removed.');
  }
  if (
    input.entryType === 'REFUND' ||
    input.entryType === 'WAITING_COLLECTION' ||
    input.entryType === 'TOP_UP'
  ) {
    reasons.push('Refunds, top-ups, and waiting-charge collections are retained.');
  }
  if (input.relatedOrderId && input.entryType === 'ADJUSTMENT') {
    reasons.push('This adjustment is tied to an order and is retained.');
  }
  if (input.entryType !== 'ADJUSTMENT') {
    reasons.push('Only an admin adjustment can be cleaned up from the customer wallet.');
  }
  if (reasons.length > 0) {
    return refused(reasons, input.balance);
  }
  const amount = cents(input.amount);
  const delta = input.direction === 'CREDIT' ? -amount : amount;
  const projected = cents(input.balance) + delta;
  if (projected < 0) {
    return refused(
      ['The reversal would make the customer wallet balance negative, which this ledger does not allow.'],
      input.balance,
    );
  }
  return {
    allowed: true,
    reasons: [],
    balance_delta_cents: delta,
    projected_balance: centsToInr(projected),
  };
}
