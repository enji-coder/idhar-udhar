import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { OrderStateMachine } from './order-state-machine';
import { OrdersService } from './orders.service';

const CITY = '99999999-9999-4999-8999-999999999999';
const CUSTOMER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const TRUCK = '11111111-1111-4111-8111-111111111111';
const RIDER = '22222222-2222-4222-8222-222222222222';
const ORDER = '55555555-5555-4555-8555-555555555555';

describe('dispatch after confirm', () => {
  it('creates SYSTEM offers for eligible online riders after SEARCHING', async () => {
    const searchingOrder = {
      order_id: ORDER,
      display_id: 'IU-AMD-0000000001',
      customer_profile_id: CUSTOMER,
      rider_profile_id: null,
      city_id: CITY,
      city_code: 'AMD',
      vehicle_category_id: TRUCK,
      vehicle_category_name_snapshot: 'Truck',
      vehicle_id: null,
      canonical_status: 'SEARCHING',
      package_weight_kg: '10.000',
      parent_order_id: null,
      scheduled_at: null,
      created_at: new Date('2026-09-28T00:00:00.000Z'),
      updated_at: new Date('2026-09-28T00:00:00.000Z'),
    };
    const offer = {
      order_offer_id: '66666666-6666-4666-8666-666666666666',
      order_id: ORDER,
      rider_profile_id: RIDER,
      status: 'PENDING',
      created_at: new Date('2026-09-28T00:00:00.000Z'),
      responded_at: null,
    };
    const orders = {
      lockById: jest.fn(async () => searchingOrder),
      findSnapshotByOrder: undefined,
      insertOffer: jest.fn(async () => offer),
      riderHasLiveOrder: jest.fn(async () => false),
      listStops: jest.fn(async () => [
        { stop_type: 'PICKUP', latitude: '23.030000', longitude: '72.570000' },
      ]),
      listRiderIdsWithOffers: jest.fn(async () => []),
      compareAndSetStatus: jest.fn(async () => ({
        ...searchingOrder,
        canonical_status: 'OFFERED',
      })),
      insertStatusEvent: jest.fn(async () => undefined),
    };
    const catalog = {
      listEligibleOnlineRidersForCategory: jest.fn(async () => [RIDER]),
      findRider: jest.fn(async () => ({
        rider_profile_id: RIDER,
        approval_status: 'APPROVED',
        online_status: 'ONLINE',
        cod_operational_status: 'OK',
        deactivated_at: null,
      })),
    };
    const fares = {
      findSnapshotByOrder: jest.fn(async () => ({
        fare_snapshot_id: '77777777-7777-4777-8777-777777777777',
        order_id: ORDER,
      })),
    };
    const notifications = {
      onStatusChange: jest.fn(async () => undefined),
      onNewOffer: jest.fn(async () => undefined),
      onOffersUnavailable: jest.fn(async () => undefined),
    };
    const walletCod = {
      assertNotSuspended: jest.fn(async () => undefined),
    };
    const service = new OrdersService(
      {
        transaction: async (work: (db: object) => Promise<unknown>) => work({}),
      } as never,
      orders as never,
      catalog as never,
      fares as never,
      {} as never,
      {} as never,
      { find: jest.fn(async () => null), insert: jest.fn(async () => undefined) } as never,
      new OrderStateMachine(),
      { getOrThrow: jest.fn(() => ({ offerTtlSeconds: 300 })) } as never,
      walletCod as never,
      notifications as never,
      {} as never,
      { captureOnDelivered: jest.fn(async () => undefined) } as never,
      {
        getRiderLocationForConsumer: jest.fn(async () => ({
          stale: false,
          location: { latitude: 23.0225, longitude: 72.5714 },
        })),
      } as never,
    );

    const result = await service.dispatchOffersForSearchingOrder(ORDER);
    expect(result).toEqual({ offered: 1 });
    expect(orders.insertOffer).toHaveBeenCalledWith(
      { orderId: ORDER, riderProfileId: RIDER },
      expect.anything(),
    );
    expect(notifications.onNewOffer).toHaveBeenCalled();
  });

  it('offers the nearer fresh rider and skips a stale one', async () => {
    const near = '33333333-3333-4333-8333-333333333333';
    const far = '44444444-4444-4444-8444-444444444444';
    const orders = {
      lockById: jest.fn(async () => ({
        ...searchingOrder(),
      })),
      insertOffer: jest.fn(async () => ({
        order_offer_id: '66666666-6666-4666-8666-666666666666',
        order_id: ORDER,
        rider_profile_id: near,
        status: 'PENDING',
        created_at: new Date('2026-09-28T00:00:00.000Z'),
        responded_at: null,
      })),
      riderHasLiveOrder: jest.fn(async () => false),
      listStops: jest.fn(async () => [
        { stop_type: 'PICKUP', latitude: '23.030000', longitude: '72.570000' },
      ]),
      listRiderIdsWithOffers: jest.fn(async () => []),
      compareAndSetStatus: jest.fn(async () => ({
        ...searchingOrder(),
        canonical_status: 'OFFERED',
      })),
      insertStatusEvent: jest.fn(async () => undefined),
    };
    const locations = new Map([
      [far, { stale: true, location: { latitude: 23.031, longitude: 72.571 } }],
      [near, { stale: false, location: { latitude: 23.031, longitude: 72.571 } }],
      [RIDER, { stale: false, location: { latitude: 23.2, longitude: 72.8 } }],
    ]);
    const service = buildService({
      orders,
      candidates: [far, RIDER, near],
      locationFor: async (id: string) => locations.get(id),
    });

    const result = await service.dispatchOffersForSearchingOrder(ORDER);

    expect(result).toEqual({ offered: 1 });
    expect(orders.insertOffer).toHaveBeenCalledTimes(1);
    expect(orders.insertOffer).toHaveBeenCalledWith(
      { orderId: ORDER, riderProfileId: near },
      expect.anything(),
    );
  });

  it('does not create an offer when the only online rider has a stale location', async () => {
    const orders = {
      lockById: jest.fn(async () => searchingOrder()),
      insertOffer: jest.fn(),
      riderHasLiveOrder: jest.fn(async () => false),
      listStops: jest.fn(async () => [
        { stop_type: 'PICKUP', latitude: '23.030000', longitude: '72.570000' },
      ]),
      listRiderIdsWithOffers: jest.fn(async () => []),
    };
    const service = buildService({
      orders,
      candidates: [RIDER],
      locationFor: async () => ({
        stale: true,
        location: { latitude: 23.03, longitude: 72.57 },
      }),
    });

    const result = await service.dispatchOffersForSearchingOrder(ORDER);

    expect(result).toEqual({ offered: 0 });
    expect(orders.insertOffer).not.toHaveBeenCalled();
  });

  it('retries dispatch when the customer reads a searching order', async () => {
    const searching = searchingOrder();
    const offered = { ...searching, canonical_status: 'OFFERED' };
    const orders = {
      findById: jest
        .fn()
        .mockResolvedValueOnce(searching)
        .mockResolvedValueOnce(offered),
      lockById: jest.fn(async () => searching),
      insertOffer: jest.fn(async () => ({
        order_offer_id: '66666666-6666-4666-8666-666666666666',
        order_id: ORDER,
        rider_profile_id: RIDER,
        status: 'PENDING',
        created_at: new Date('2026-09-28T00:00:00.000Z'),
        responded_at: null,
      })),
      riderHasLiveOrder: jest.fn(async () => false),
      listStops: jest.fn(async () => [
        {
          order_stop_id: '88888888-8888-4888-8888-888888888888',
          sequence: 0,
          stop_type: 'PICKUP',
          address_text: 'Pickup',
          latitude: '23.030000',
          longitude: '72.570000',
          zone_id: null,
          contact_name: null,
          contact_phone: null,
          proof_file_id: null,
        },
      ]),
      listRiderIdsWithOffers: jest.fn(async () => []),
      compareAndSetStatus: jest.fn(async () => offered),
      insertStatusEvent: jest.fn(async () => undefined),
      findCustomerRating: jest.fn(async () => null),
    };
    const service = buildService({
      orders,
      candidates: [RIDER],
      locationFor: async () => ({
        stale: false,
        location: { latitude: 23.031, longitude: 72.571 },
      }),
      settlement: { waitingSummary: jest.fn(async () => null) },
      catalogExtra: { findAssignedRiderDisplay: jest.fn(async () => null) },
      fares: {
        findSnapshotByOrder: jest.fn(async () => ({
          fare_snapshot_id: '77777777-7777-4777-8777-777777777777',
          order_id: ORDER,
          fare_config_version_id: '99999999-9999-4999-8999-999999999991',
          vehicle_category_id: TRUCK,
          vehicle_category_name: 'Truck',
          distance_km: '1.200',
          stop_count: 2,
          base_fare: '40.00',
          per_km: '10.00',
          distance_charge: '12.00',
          initial_minimum: '40.00',
          waiting: '0.00',
          surge: '0.00',
          toll: '0.00',
          parking: '0.00',
          initial_waiting_minutes: 0,
          waiting_charge_per_minute: '0.00',
          trip_fare: '52.00',
          discount: '0.00',
          rounding: '0.00',
          net_payable: '52.00',
          tax: '0.00',
          quoted_at: new Date('2026-09-28T00:00:00.000Z'),
          confirmed_at: new Date('2026-09-28T00:00:00.000Z'),
        })),
      },
    });

    const body = await service.getById(
      {
        identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        role: 'CUSTOMER',
        profileId: CUSTOMER,
      },
      ORDER,
    );

    expect(orders.insertOffer).toHaveBeenCalledWith(
      { orderId: ORDER, riderProfileId: RIDER },
      expect.anything(),
    );
    expect(body.canonical_status).toBe('OFFERED');
  });

  it('keeps active online riders eligible and excludes only deactivated riders', () => {
    const src = readFileSync(join(__dirname, 'catalog.repository.ts'), 'utf8');
    const start = src.indexOf('async listEligibleOnlineRidersForCategory');
    const end = src.indexOf('async findAssignedRiderDisplay');
    const query = src.slice(start, end);
    expect(query).toContain("r.online_status = 'ONLINE'");
    expect(query).toContain("r.approval_status = 'APPROVED'");
    expect(query).toContain('r.deactivated_at IS NULL');
    expect(query).toContain('v.active = TRUE');
    expect(query).toContain('v.vehicle_category_id = $1');
    expect(query).not.toContain('deactivated_at IS NOT NULL');
  });
});

function searchingOrder() {
  return {
    order_id: ORDER,
    display_id: 'IU-AMD-0000000001',
    crn: null,
    customer_profile_id: CUSTOMER,
    rider_profile_id: null,
    city_id: CITY,
    city_code: 'AMD',
    vehicle_category_id: TRUCK,
    vehicle_category_name_snapshot: 'Truck',
    vehicle_id: null,
    canonical_status: 'SEARCHING' as const,
    package_weight_kg: '10.000',
    parent_order_id: null,
    scheduled_at: null,
    created_at: new Date('2026-09-28T00:00:00.000Z'),
    updated_at: new Date('2026-09-28T00:00:00.000Z'),
  };
}

function buildService(input: {
  orders: Record<string, unknown>;
  candidates: string[];
  locationFor: (riderProfileId: string) => Promise<unknown>;
  settlement?: Record<string, unknown>;
  catalogExtra?: Record<string, unknown>;
  fares?: Record<string, unknown>;
}) {
  const notifications = {
    onStatusChange: jest.fn(async () => undefined),
    onNewOffer: jest.fn(async () => undefined),
    onOffersUnavailable: jest.fn(async () => undefined),
  };
  return new OrdersService(
    {
      transaction: async (work: (db: object) => Promise<unknown>) => work({}),
    } as never,
    input.orders as never,
    {
      listEligibleOnlineRidersForCategory: jest.fn(async () => input.candidates),
      findRider: jest.fn(async (id: string) => ({
        rider_profile_id: id,
        approval_status: 'APPROVED',
        online_status: 'ONLINE',
        cod_operational_status: 'CLEAR',
        deactivated_at: null,
      })),
      ...(input.catalogExtra ?? {}),
    } as never,
    (input.fares ?? {
      findSnapshotByOrder: jest.fn(async () => ({
        fare_snapshot_id: '77777777-7777-4777-8777-777777777777',
        order_id: ORDER,
      })),
    }) as never,
    {} as never,
    {} as never,
    { find: jest.fn(async () => null), insert: jest.fn(async () => undefined) } as never,
    new OrderStateMachine(),
    { getOrThrow: jest.fn(() => ({ offerTtlSeconds: 300 })) } as never,
    { assertNotSuspended: jest.fn(async () => undefined) } as never,
    notifications as never,
    (input.settlement ?? {}) as never,
    { captureOnDelivered: jest.fn(async () => undefined) } as never,
    {
      getRiderLocationForConsumer: jest.fn((id: string) => input.locationFor(id)),
    } as never,
  );
}
