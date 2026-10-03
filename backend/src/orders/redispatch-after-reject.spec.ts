import { OrderStateMachine } from './order-state-machine';
import { OrdersService } from './orders.service';

const RIDER = '22222222-2222-4222-8222-222222222222';
const OTHER = '33333333-3333-4333-8333-333333333333';
const ORDER = '55555555-5555-4555-8555-555555555555';
const OFFER = '66666666-6666-4666-8666-666666666666';

describe('redispatch after last reject', () => {
  it('returns SEARCHING then redispatches eligible riders', async () => {
    const offeredOrder = {
      order_id: ORDER,
      display_id: 'IU-1',
      customer_profile_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      rider_profile_id: null,
      city_id: '99999999-9999-4999-8999-999999999999',
      city_code: 'AMD',
      vehicle_category_id: '11111111-1111-4111-8111-111111111111',
      vehicle_category_name_snapshot: 'Bike',
      vehicle_id: null,
      canonical_status: 'OFFERED',
      package_weight_kg: '5.000',
      parent_order_id: null,
      scheduled_at: null,
      created_at: new Date('2026-10-03T00:00:00.000Z'),
      updated_at: new Date('2026-10-03T00:00:00.000Z'),
    };
    const searchingOrder = { ...offeredOrder, canonical_status: 'SEARCHING' };
    const offer = {
      order_offer_id: OFFER,
      order_id: ORDER,
      rider_profile_id: RIDER,
      status: 'PENDING',
      created_at: new Date('2026-10-03T00:00:00.000Z'),
      responded_at: null,
    };
    const orders = {
      findOffer: jest.fn(async () => offer),
      lockById: jest.fn(async () => {
        // After reject transition, subsequent locks see SEARCHING.
        if (orders.compareAndSetStatus.mock.calls.length > 0) {
          return searchingOrder;
        }
        return offeredOrder;
      }),
      lockOffer: jest.fn(async () => offer),
      updateOfferStatus: jest.fn(async () => ({ ...offer, status: 'REJECTED' })),
      countPendingOffers: jest.fn(async () => 0),
      compareAndSetStatus: jest.fn(async () => searchingOrder),
      insertStatusEvent: jest.fn(async () => undefined),
      riderHasLiveOrder: jest.fn(async () => false),
      insertOffer: jest.fn(async () => ({
        order_offer_id: '88888888-8888-4888-8888-888888888888',
        order_id: ORDER,
        rider_profile_id: OTHER,
        status: 'PENDING',
        created_at: new Date(),
        responded_at: null,
      })),
    };
    const catalog = {
      findRider: jest.fn(async () => ({
        rider_profile_id: RIDER,
        approval_status: 'APPROVED',
        online_status: 'ONLINE',
        deactivated_at: null,
      })),
      listEligibleOnlineRidersForCategory: jest.fn(async () => [OTHER]),
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
      { assertNotSuspended: jest.fn(async () => undefined) } as never,
      notifications as never,
      {} as never,
      { captureOnDelivered: jest.fn(async () => undefined) } as never,
      { getRiderLocationForConsumer: jest.fn() } as never,
    );

    const result = await service.rejectOffer(
      { role: 'RIDER', profileId: RIDER, identityId: 'id-1' } as never,
      OFFER,
    );
    expect(result.order.canonical_status).toBe('SEARCHING');
    expect(orders.insertOffer).toHaveBeenCalled();
    expect(notifications.onNewOffer).toHaveBeenCalled();
  });
});
