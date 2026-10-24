import { LIVE_RIDER_STATUSES, OrderStatus } from './order-status';

/** Statuses still being dispatched or carried. They are not historical. */
const ACTIVE_STATUSES: ReadonlySet<OrderStatus> = new Set([
  'SEARCHING',
  'OFFERED',
  ...LIVE_RIDER_STATUSES,
]);

export type OrderDependencyCounts = {
  payments: number;
  wallet: number;
  cod: number;
  customer_wallet: number;
  receivables: number;
  invoices: number;
  finance: number;
  cancellations: number;
  adjustments: number;
  resends: number;
  tax: number;
  children: number;
  /** Every pickup-waiting row, including VOID and zero-amount OPEN assessments. */
  waiting: number;
};

export type DeletionDecision = {
  allowed: boolean;
  code: 'ORDER_DELETE_BLOCKED' | 'ORDER_FINANCIAL_DEPENDENCY' | null;
  message: string;
  blockers: string[];
};

const BLOCKER_LABELS: Record<keyof OrderDependencyCounts, string> = {
  payments: 'payment transactions',
  wallet: 'rider wallet ledger entries',
  cod: 'COD ledger entries',
  customer_wallet: 'customer wallet ledger entries',
  receivables: 'customer receivable entries',
  invoices: 'invoices',
  finance: 'finance snapshots',
  cancellations: 'cancellation snapshots',
  adjustments: 'order adjustments',
  resends: 'resend snapshots',
  tax: 'tax snapshots',
  children: 'child orders',
  waiting: 'pickup waiting charges',
};

export function isActiveOrderStatus(status: OrderStatus): boolean {
  return ACTIVE_STATUSES.has(status);
}

/**
 * Hard purge is for historical orders with no money movement.
 * Age, completion, and cancellation are not blockers. Settled money is.
 * Active trips stay until they leave the live lifecycle.
 */
export function decideOrderPurge(
  status: OrderStatus,
  counts: OrderDependencyCounts,
): DeletionDecision {
  if (isActiveOrderStatus(status)) {
    return {
      allowed: false,
      code: 'ORDER_DELETE_BLOCKED',
      message:
        'This order is still active. Cancel it or wait until it is finished before deleting it.',
      blockers: [`active status ${status}`],
    };
  }
  const blockers = (Object.keys(BLOCKER_LABELS) as Array<keyof OrderDependencyCounts>)
    .filter((key) => counts[key] > 0)
    .map((key) => BLOCKER_LABELS[key]);
  if (blockers.length > 0) {
    return {
      allowed: false,
      code: 'ORDER_FINANCIAL_DEPENDENCY',
      message:
        'This order has financial or linked records that must be kept. It can be removed from the operations list without deleting those records.',
      blockers,
    };
  }
  return {
    allowed: true,
    code: null,
    message: 'Eligible for permanent deletion.',
    blockers: [],
  };
}

export function decideOrderHide(status: OrderStatus): DeletionDecision {
  if (isActiveOrderStatus(status)) {
    return {
      allowed: false,
      code: 'ORDER_DELETE_BLOCKED',
      message:
        'An active order cannot be hidden from operations while riders or customers are still using it.',
      blockers: [`active status ${status}`],
    };
  }
  return {
    allowed: true,
    code: null,
    message: 'Eligible to hide from operations. Financial records stay.',
    blockers: [],
  };
}
