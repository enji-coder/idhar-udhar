import { createHash } from 'node:crypto';

export type ParsedCashfreePayoutEvent =
  | {
      kind: 'transfer';
      eventType: string;
      merchantTransferId: string;
      providerTransferId: string | null;
      providerStatus: string;
      failureReason: string | null;
    }
  | { kind: 'ignored'; eventType: string };

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

export function parseCashfreePayoutWebhook(body: unknown): ParsedCashfreePayoutEvent {
  const root = asRecord(body);
  if (!root) {
    return { kind: 'ignored', eventType: 'UNKNOWN' };
  }
  const eventType = typeof root.type === 'string' ? root.type : 'UNKNOWN';
  const data = asRecord(root.data) ?? root;
  const merchantTransferId =
    typeof data.transfer_id === 'string' ? data.transfer_id.trim() : '';
  const providerStatus =
    typeof data.status === 'string' ? data.status.trim().toUpperCase() : '';
  if (!merchantTransferId || !providerStatus) {
    return { kind: 'ignored', eventType };
  }
  const providerTransferId =
    data.cf_transfer_id === undefined || data.cf_transfer_id === null
      ? null
      : String(data.cf_transfer_id);
  const failureReason =
    typeof data.status_description === 'string'
      ? data.status_description.slice(0, 300)
      : null;
  return {
    kind: 'transfer',
    eventType,
    merchantTransferId,
    providerTransferId,
    providerStatus,
    failureReason,
  };
}

export function cashfreePayoutEventId(rawBody: string): string {
  return createHash('sha256').update(`payout:${rawBody}`).digest('hex').slice(0, 64);
}
