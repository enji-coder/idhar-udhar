import { formatInr } from '../fare/money';

/**
 * Customer invoice amounts copied from the confirmed fare snapshot.
 * billed_total is the snapshot net payable plus the locked waiting charge.
 * GST stays 0. Commission is not part of this document.
 */
export type InvoiceSnapshotFare = {
  tripFare: string;
  discount: string;
  rounding: string;
  netPayable: string;
};

export function invoiceFareFromSnapshot(row: {
  trip_fare: string;
  discount: string;
  rounding: string;
  net_payable: string;
}): InvoiceSnapshotFare {
  return {
    tripFare: formatInr(row.trip_fare),
    discount: formatInr(row.discount),
    rounding: formatInr(row.rounding),
    netPayable: formatInr(row.net_payable),
  };
}

export function invoiceBilledTotal(netPayable: string, additional: string): string {
  return addInr(netPayable, additional);
}

export type InvoiceLineRecord = {
  sequence: number;
  line_type: string;
  label: string;
  amount: string;
};

export type InvoiceHeaderRecord = {
  invoice_number: string;
  status: string;
  issued_at: Date | string | null;
  trip_fare: string;
  discount: string;
  additional_locked_charges: string;
  rounding: string;
  billed_total: string;
  customer_paid: string;
  receiver_paid: string;
  payment_status_snapshot: string | null;
  order_id: string;
  crn: string;
  canonical_status: string;
  pickup_address: string | null;
  pickup_contact_name: string | null;
  pickup_contact_phone: string | null;
  drop_address: string | null;
  drop_contact_name: string | null;
  drop_contact_phone: string | null;
  trip_completed_at: Date | string | null;
  vehicle_category: string | null;
  vehicle_registration: string | null;
  customer_planned_online: string | null;
  customer_planned_cash: string | null;
  receiver_planned_online: string | null;
  receiver_planned_cash: string | null;
};

export type CustomerInvoiceDocument = {
  invoice_number: string;
  crn: string;
  status: string;
  issued_at: string | null;
  trip_completed_at: string | null;
  pickup: {
    address: string | null;
    contact_name: string | null;
    contact_phone: string | null;
  };
  drop: {
    address: string | null;
    contact_name: string | null;
    contact_phone: string | null;
  };
  vehicle: {
    category: string | null;
    registration: string | null;
  };
  lines: Array<{
    sequence: number;
    line_type: string;
    label: string;
    amount: string;
  }>;
  trip_fare: string;
  discount: string;
  additional_charges: string;
  subtotal: string;
  rounding: string;
  net_payable: string;
  payment: {
    status: string | null;
    customer_paid: string;
    receiver_paid: string;
    customer_planned_online: string | null;
    customer_planned_cash: string | null;
    receiver_planned_online: string | null;
    receiver_planned_cash: string | null;
  };
};

const HIDDEN_LINE = /commission|rider_share|company_share|gst|tax/i;

export function toCustomerInvoice(
  header: InvoiceHeaderRecord,
  lines: InvoiceLineRecord[],
): CustomerInvoiceDocument {
  const tripFare = formatInr(header.trip_fare);
  const discount = formatInr(header.discount);
  const additional = formatInr(header.additional_locked_charges);
  const rounding = formatInr(header.rounding);
  const netPayable = formatInr(header.billed_total);
  return {
    invoice_number: header.invoice_number,
    crn: header.crn,
    status: header.status,
    issued_at: isoOrNull(header.issued_at),
    trip_completed_at: isoOrNull(header.trip_completed_at),
    pickup: {
      address: header.pickup_address,
      contact_name: header.pickup_contact_name,
      contact_phone: header.pickup_contact_phone,
    },
    drop: {
      address: header.drop_address,
      contact_name: header.drop_contact_name,
      contact_phone: header.drop_contact_phone,
    },
    vehicle: {
      category: header.vehicle_category,
      registration: header.vehicle_registration,
    },
    lines: lines
      .filter((line) => !HIDDEN_LINE.test(line.line_type) && !HIDDEN_LINE.test(line.label))
      .map((line) => ({
        sequence: line.sequence,
        line_type: line.line_type,
        label: line.label,
        amount: formatInr(line.amount),
      })),
    trip_fare: tripFare,
    discount,
    additional_charges: additional,
    subtotal: subtractInr(netPayable, rounding),
    rounding,
    net_payable: netPayable,
    payment: {
      status: header.payment_status_snapshot,
      customer_paid: formatInr(header.customer_paid),
      receiver_paid: formatInr(header.receiver_paid),
      customer_planned_online: moneyOrNull(header.customer_planned_online),
      customer_planned_cash: moneyOrNull(header.customer_planned_cash),
      receiver_planned_online: moneyOrNull(header.receiver_planned_online),
      receiver_planned_cash: moneyOrNull(header.receiver_planned_cash),
    },
  };
}

export function collectKeys(value: unknown, found = new Set<string>()): Set<string> {
  if (Array.isArray(value)) {
    for (const item of value) {
      collectKeys(item, found);
    }
    return found;
  }
  if (value !== null && typeof value === 'object') {
    for (const [key, child] of Object.entries(value)) {
      found.add(key);
      collectKeys(child, found);
    }
  }
  return found;
}

function moneyOrNull(value: string | null): string | null {
  if (value == null) {
    return null;
  }
  return formatInr(value);
}

function isoOrNull(value: Date | string | null): string | null {
  if (value == null) {
    return null;
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date.toISOString();
}

function paise(value: string): bigint {
  const formatted = formatInr(value);
  const negative = formatted.startsWith('-');
  const unsigned = negative ? formatted.slice(1) : formatted;
  const [whole, frac] = unsigned.split('.');
  const amount = BigInt(whole) * 100n + BigInt(frac);
  return negative ? -amount : amount;
}

function fromPaise(amount: bigint): string {
  const negative = amount < 0n;
  const abs = negative ? -amount : amount;
  const whole = abs / 100n;
  const frac = (abs % 100n).toString().padStart(2, '0');
  return `${negative ? '-' : ''}${whole.toString()}.${frac}`;
}

export function addInr(left: string, right: string): string {
  return fromPaise(paise(left) + paise(right));
}

export function subtractInr(left: string, right: string): string {
  return fromPaise(paise(left) - paise(right));
}
