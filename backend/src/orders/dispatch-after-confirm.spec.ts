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
});
