import { AuthContext } from '../auth/types/auth-context';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { OrdersRepository, RiderHistoryOrderRow } from './orders.repository';

/** Terminal trips shown in rider Trip History. Live orders stay off this list. */
export const RIDER_HISTORY_STATUSES = [
  'DELIVERED',
  'CANCELLED',
  'RESEND_COMPLETED',
] as const;

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type RiderHistoryCursor = {
  createdAt: Date;
  orderId: string;
};

/**
 * `GET /v1/rider/orders?limit=&cursor=`
 *
 * Response: `{ orders, next_cursor }`. `next_cursor` is null on the last page.
 * Cursor is `{created_at ISO}_{order_id}` and pages by
 * `(created_at, order_id) DESC` so rows are not skipped or repeated.
 */
export function parseRiderHistoryQuery(
  limitRaw?: string,
  cursorRaw?: string,
): { limit: number; cursor: RiderHistoryCursor | null } {
  return {
    limit: parseLimit(limitRaw),
    cursor: parseCursor(cursorRaw),
  };
}

export function encodeRiderHistoryCursor(createdAt: Date, orderId: string): string {
  return `${createdAt.toISOString()}_${orderId}`;
}

export function serializeRiderHistoryOrder(row: RiderHistoryOrderRow) {
  return {
    order_id: row.order_id,
    display_id: row.display_id,
    crn: row.crn ?? null,
    canonical_status: row.canonical_status,
    created_at: row.created_at.toISOString(),
    updated_at: row.updated_at.toISOString(),
    pickup_address: row.pickup_address ?? null,
    drop_address: row.drop_address ?? null,
  };
}

export async function listRiderOrderHistory(
  auth: AuthContext,
  orders: OrdersRepository,
  limitRaw?: string,
  cursorRaw?: string,
) {
  if (auth.role !== 'RIDER') {
    throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider role required', 403);
  }
  const parsed = parseRiderHistoryQuery(limitRaw, cursorRaw);
  const rows = await orders.listRiderHistory({
    riderProfileId: auth.profileId,
    limit: parsed.limit,
    cursorCreatedAt: parsed.cursor?.createdAt,
    cursorOrderId: parsed.cursor?.orderId,
  });
  const last = rows[rows.length - 1];
  return {
    orders: rows.map((row) => serializeRiderHistoryOrder(row)),
    next_cursor:
      rows.length === parsed.limit && last
        ? encodeRiderHistoryCursor(last.created_at, last.order_id)
        : null,
  };
}

function parseLimit(raw?: string): number {
  if (raw == null || raw.trim() === '') {
    return DEFAULT_LIMIT;
  }
  if (!/^[0-9]+$/.test(raw.trim())) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'limit must be a positive integer',
      400,
    );
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < 1) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'limit must be a positive integer',
      400,
    );
  }
  return Math.min(parsed, MAX_LIMIT);
}

function parseCursor(cursor?: string): RiderHistoryCursor | null {
  if (cursor == null || cursor.trim() === '') {
    return null;
  }
  const sep = cursor.indexOf('_');
  if (sep < 1) {
    throw new ApiError(ErrorCodes.VALIDATION_ERROR, 'cursor is invalid', 400);
  }
  const createdAt = new Date(cursor.slice(0, sep));
  const orderId = cursor.slice(sep + 1);
  if (Number.isNaN(createdAt.getTime()) || !UUID.test(orderId)) {
    throw new ApiError(ErrorCodes.VALIDATION_ERROR, 'cursor is invalid', 400);
  }
  return { createdAt, orderId };
}
