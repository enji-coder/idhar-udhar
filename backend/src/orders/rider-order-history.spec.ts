import { AuthContext } from '../auth/types/auth-context';
import { ApiError } from '../common/errors/api-error';
import { OrdersRepository, RiderHistoryOrderRow } from './orders.repository';
import { listRiderOrderHistory } from './rider-order-history';

const riderA = '11111111-1111-4111-8111-111111111111';
const riderB = '22222222-2222-4222-8222-222222222222';

function auth(profileId: string, role: AuthContext['role'] = 'RIDER'): AuthContext {
  return {
    identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    role,
    profileId,
  };
}

function row(id: string, status: string, at: string): RiderHistoryOrderRow {
  const created = new Date(at);
  return {
    order_id: id,
    display_id: `IU-${id.slice(0, 4)}`,
    crn: `CRN-${id.slice(0, 4)}`,
    canonical_status: status,
    created_at: created,
    updated_at: created,
    pickup_address: 'Pickup',
    drop_address: 'Drop',
  };
}

function compareDesc(left: RiderHistoryOrderRow, right: RiderHistoryOrderRow): number {
  const time = right.created_at.getTime() - left.created_at.getTime();
  if (time !== 0) {
    return time;
  }
  if (left.order_id === right.order_id) {
    return 0;
  }
  return right.order_id > left.order_id ? 1 : -1;
}

function beforeCursor(
  row: RiderHistoryOrderRow,
  createdAt: Date,
  orderId: string,
): boolean {
  const time = row.created_at.getTime() - createdAt.getTime();
  if (time !== 0) {
    return time < 0;
  }
  return row.order_id < orderId;
}

describe('GET /v1/rider/orders', () => {
  const stored: RiderHistoryOrderRow[] = [
    row('10000000-0000-4000-8000-000000000005', 'DELIVERED', '2026-10-05T00:00:00.000Z'),
    row('10000000-0000-4000-8000-000000000004', 'CANCELLED', '2026-10-04T00:00:00.000Z'),
    row('10000000-0000-4000-8000-000000000003', 'RESEND_COMPLETED', '2026-10-03T00:00:00.000Z'),
    row('10000000-0000-4000-8000-000000000002', 'DELIVERED', '2026-10-02T00:00:00.000Z'),
    row('10000000-0000-4000-8000-000000000001', 'CANCELLED', '2026-10-01T00:00:00.000Z'),
    row('10000000-0000-4000-8000-000000000009', 'IN_TRANSIT', '2026-10-09T00:00:00.000Z'),
    row('20000000-0000-4000-8000-000000000001', 'CANCELLED', '2026-10-08T00:00:00.000Z'),
  ];

  function repository() {
    const queries: string[] = [];
    const owners = new Map(stored.map((item) => [item.order_id, ownerOf(item.order_id)]));
    const repo = new OrdersRepository({
      query: async (sql: string, params: unknown[] = []) => {
        queries.push(sql);
        const riderProfileId = String(params[0]);
        const limit = Number(params[1]);
        const cursorAt = params[2] ? new Date(String(params[2])) : null;
        const cursorId = params[3] ? String(params[3]) : null;
        const rows = stored
          .filter((item) => owners.get(item.order_id) === riderProfileId)
          .filter((item) =>
            ['DELIVERED', 'CANCELLED', 'RESEND_COMPLETED'].includes(
              item.canonical_status,
            ),
          )
          .filter((item) =>
            cursorAt && cursorId ? beforeCursor(item, cursorAt, cursorId) : true,
          )
          .sort(compareDesc)
          .slice(0, limit);
        return { rows };
      },
    } as never);
    return { repo, queries };
  }

  function ownerOf(orderId: string): string {
    return orderId.startsWith('2000') ? riderB : riderA;
  }

  it('returns only that rider terminal orders and does not skip or repeat pages', async () => {
    const { repo, queries } = repository();
    const seen: string[] = [];
    let cursor: string | undefined;
    let pages = 0;
    do {
      const body = await listRiderOrderHistory(auth(riderA), repo, '2', cursor);
      pages += 1;
      const ids = body.orders.map((order) => order.order_id);
      expect(ids.some((id) => seen.includes(id))).toBe(false);
      seen.push(...ids);
      expect(body.orders.every((order) => order.canonical_status !== 'IN_TRANSIT')).toBe(
        true,
      );
      expect(body.orders.some((order) => order.order_id.startsWith('2000'))).toBe(false);
      cursor = body.next_cursor ?? undefined;
    } while (cursor);

    expect(pages).toBe(3);
    expect(seen).toEqual([
      '10000000-0000-4000-8000-000000000005',
      '10000000-0000-4000-8000-000000000004',
      '10000000-0000-4000-8000-000000000003',
      '10000000-0000-4000-8000-000000000002',
      '10000000-0000-4000-8000-000000000001',
    ]);
    expect(queries[0]).toContain('o.rider_profile_id = $1');
    expect(queries[0]).toContain(
      "o.canonical_status IN ('DELIVERED', 'CANCELLED', 'RESEND_COMPLETED')",
    );
    expect(queries[1]).toContain(
      '(o.created_at, o.order_id) < ($3::timestamptz, $4::uuid)',
    );
  });

  it('does not query another rider when the caller is rider A', async () => {
    const { repo } = repository();
    const own = await listRiderOrderHistory(auth(riderB), repo, '20');
    expect(own.orders.map((order) => order.order_id)).toEqual([
      '20000000-0000-4000-8000-000000000001',
    ]);
    const other = await listRiderOrderHistory(auth(riderA), repo, '20');
    expect(other.orders.some((order) => order.order_id.startsWith('2000'))).toBe(false);
  });

  it('rejects a non-rider before reading orders', async () => {
    const { repo, queries } = repository();
    await expect(
      listRiderOrderHistory(auth(riderA, 'CUSTOMER'), repo, '20'),
    ).rejects.toBeInstanceOf(ApiError);
    expect(queries).toEqual([]);
  });
});
