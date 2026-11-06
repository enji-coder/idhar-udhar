import { formatInr } from '../fare/money';

/**
 * How a frozen rider earning was posted.
 * Cash trips stay on COD Due. They do not credit the earning wallet.
 */
export type EarningSettlementStatus =
  | 'CREDITED'
  | 'APPLIED_TO_COD'
  | 'CREDITED_AND_COD'
  | 'PENDING'
  | 'CASH';

/** Whether that posting is complete. Historical rows are not rewritten. */
export type EarningSettlementState = 'SETTLED' | 'PENDING';

/** Paise from already-rounded NUMERIC text. Display rounding is not used here. */
export function inrPaise(raw: string): number {
  const formatted = formatInr(raw);
  const negative = formatted.startsWith('-');
  const [whole, frac] = (negative ? formatted.slice(1) : formatted).split('.');
  const paise = Number(whole) * 100 + Number(frac);
  if (!Number.isSafeInteger(paise)) {
    throw new Error('INR amount is out of range');
  }
  return negative ? -paise : paise;
}

export function classifyEarningSettlement(input: {
  cashCollected: string;
  walletCredited: string;
  codApplied: string;
}): EarningSettlementStatus {
  const cash = inrPaise(input.cashCollected);
  const wallet = inrPaise(input.walletCredited);
  const cod = inrPaise(input.codApplied);
  if (cash > 0) {
    return 'CASH';
  }
  if (wallet > 0 && cod > 0) {
    return 'CREDITED_AND_COD';
  }
  if (wallet > 0) {
    return 'CREDITED';
  }
  if (cod > 0) {
    return 'APPLIED_TO_COD';
  }
  return 'PENDING';
}

/**
 * Cash is settled when the posted CASH_COMPANY_SHARE covers
 * GREATEST(0, cash collected − rider earning). Online is settled when the
 * wallet credit and the COD Due application add up to the frozen rider amount.
 */
export function earningSettlementState(input: {
  status: EarningSettlementStatus;
  riderAmount: string;
  cashCollected: string;
  walletCredited: string;
  codApplied: string;
  companySharePosted: string;
  companyShareWalletDebit?: string;
}): EarningSettlementState {
  const rider = inrPaise(input.riderAmount);
  if (input.status === 'CASH') {
    const due = Math.max(0, inrPaise(input.cashCollected) - rider);
    const walletDebit = inrPaise(input.companyShareWalletDebit ?? '0.00');
    const legacyCod = inrPaise(input.companySharePosted);
    return walletDebit >= due || legacyCod >= due ? 'SETTLED' : 'PENDING';
  }
  if (input.status === 'PENDING') {
    return 'PENDING';
  }
  const allocated = inrPaise(input.walletCredited) + inrPaise(input.codApplied);
  return allocated === rider ? 'SETTLED' : 'PENDING';
}
