/**
 * GST treatment of the company commission only. Never of the customer fare,
 * which stays 0 by locked business decision and by database CHECK constraint.
 *
 * PostgreSQL NUMERIC(12,2) remains the financial authority: the report and the
 * freeze both compute these amounts in SQL. This module exists so the same
 * formulas can be unit-tested and cross-checked against the SQL, and it uses
 * exact BigInt paise arithmetic rather than IEEE-754, matching money.ts policy.
 *
 * The 85/15 split and the 50%-of-commission operational cost are inputs here.
 * They are read from the immutable order_finance_snapshots row and are never
 * recomputed or redefined by GST.
 */

import { formatInr } from '../fare/money';

export type GstBasis = 'NONE' | 'INCLUSIVE' | 'EXCLUSIVE';

export const GST_BASES: readonly GstBasis[] = ['NONE', 'INCLUSIVE', 'EXCLUSIVE'];

/** percent_100 is NUMERIC(5,2): 0.00 to 100.00. */
const PERCENT_PATTERN = /^(?:\d{1,3})(?:\.\d{1,2})?$/;

export type GstAllocationInput = {
  companyCommissionAmount: string;
  operationalCostAmount: string;
  gstRate: string;
  basis: GstBasis;
};

export type GstAllocation = {
  gst_rate: string;
  gst_calculation_basis: GstBasis;
  company_commission_amount: string;
  taxable_company_amount: string;
  gst_amount: string;
  operational_cost_amount: string;
  company_profit_amount: string;
};

export function isGstBasis(value: unknown): value is GstBasis {
  return typeof value === 'string' && GST_BASES.includes(value as GstBasis);
}

export function parsePercent(raw: string): string {
  if (!PERCENT_PATTERN.test(raw)) {
    throw new Error(`Invalid percent numeric text: ${raw}`);
  }
  const scaled = toScaledPercent(raw);
  if (scaled > 1_000_000n) {
    throw new Error(`Percent out of range: ${raw}`);
  }
  const [whole, frac = ''] = raw.split('.');
  return `${whole}.${(frac + '00').slice(0, 2)}`;
}

/** Rupee text to exact paise. */
function toPaise(raw: string): bigint {
  const formatted = formatInr(raw);
  const negative = formatted.startsWith('-');
  const [whole, frac] = (negative ? formatted.slice(1) : formatted).split('.');
  const paise = BigInt(whole) * 100n + BigInt(frac);
  return negative ? -paise : paise;
}

function fromPaise(paise: bigint): string {
  const negative = paise < 0n;
  const abs = negative ? -paise : paise;
  const whole = abs / 100n;
  const frac = abs % 100n;
  const text = `${whole}.${frac.toString().padStart(2, '0')}`;
  return negative ? `-${text}` : text;
}

/** Percent text to hundredths of a percent, e.g. "18.00" -> 180000n / 10000. */
function toScaledPercent(raw: string): bigint {
  const [whole, frac = ''] = raw.split('.');
  return BigInt(whole) * 10_000n + BigInt((frac + '00').slice(0, 2)) * 100n;
}

/**
 * Half-away-from-zero division, matching PostgreSQL ROUND() on NUMERIC.
 * Inputs here are non-negative, but the sign is handled for safety.
 */
function roundedDiv(numerator: bigint, denominator: bigint): bigint {
  if (denominator <= 0n) {
    throw new Error('denominator must be positive');
  }
  if (numerator < 0n) {
    return -roundedDiv(-numerator, denominator);
  }
  return (2n * numerator + denominator) / (2n * denominator);
}

/**
 * Splits an already-frozen company commission into taxable value and GST, then
 * derives the reportable company profit.
 *
 * INCLUSIVE  the commission already contains GST:
 *            taxable = ROUND(commission * 100 / (100 + rate), 2)
 *            gst     = commission - taxable
 * EXCLUSIVE  GST is computed on the commission and funded out of it:
 *            taxable = commission
 *            gst     = ROUND(commission * rate / 100, 2)
 * NONE       no GST is applied.
 *
 * profit = commission - gst - operational_cost. It may be negative when an
 * EXCLUSIVE rate is high enough to exhaust the commission; that is surfaced
 * rather than clamped.
 */
export function allocateGst(input: GstAllocationInput): GstAllocation {
  const commission = toPaise(input.companyCommissionAmount);
  const operational = toPaise(input.operationalCostAmount);
  if (commission < 0n || operational < 0n) {
    throw new Error('commission and operational cost cannot be negative');
  }
  const rate = parsePercent(input.gstRate);
  const scaledRate = toScaledPercent(rate);

  if (input.basis === 'NONE' && scaledRate !== 0n) {
    throw new Error('NONE basis requires a 0 GST rate');
  }

  let taxable: bigint;
  let gst: bigint;
  if (input.basis === 'NONE') {
    taxable = commission;
    gst = 0n;
  } else if (input.basis === 'INCLUSIVE') {
    taxable = roundedDiv(commission * 1_000_000n, 1_000_000n + scaledRate);
    gst = commission - taxable;
  } else {
    taxable = commission;
    gst = roundedDiv(commission * scaledRate, 1_000_000n);
  }

  return {
    gst_rate: rate,
    gst_calculation_basis: input.basis,
    company_commission_amount: fromPaise(commission),
    taxable_company_amount: fromPaise(taxable),
    gst_amount: fromPaise(gst),
    operational_cost_amount: fromPaise(operational),
    company_profit_amount: fromPaise(commission - gst - operational),
  };
}

/** Exact sum of 2-decimal INR text, for report totals asserted against SQL SUM(). */
export function sumInr(values: readonly string[]): string {
  return fromPaise(values.reduce((total, value) => total + toPaise(value), 0n));
}
