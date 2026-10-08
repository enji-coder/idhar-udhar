import { OrderStateMachine } from './order-state-machine';
import { OrdersService } from './orders.service';
import { plannedTripDurationSeconds } from '../routing/trip-duration';

const SESSION = '11111111-1111-4111-8111-111111111111';
const CANONICAL = '22222222-2222-4222-8222-222222222222';
const ORDER = '55555555-5555-4555-8555-555555555555';

describe('rider offer payload', () => {
  it('lists the offer for the canonical rider profile and keeps full trip fare', async () => {
    const createdAt = new Date();
    const orders = {
      expirePendingOffersOlderThan: jest.fn(async () => []),
      listSearchingOrderIdsForRider: jest.fn(async () => []),
      listOffersForRider: jest.fn(async () => [
        {
          order_offer_id: '66666666-6666-4666-8666-666666666666',
          order_id: ORDER,
          rider_profile_id: CANONICAL,
          status: 'PENDING',
          created_at: createdAt,
          responded_at: null,
          display_id: 'IU-AMD-0000000009',
          crn: 'IU-CRN-AMD-0000000009',
          canonical_status: 'OFFERED',
          vehicle_category_name: 'Bike',
          package_weight_kg: '2.000',
          trip_fare: '500.00',
          distance_km: '1.300',
          rider_amount: '425.00',
          pickup_address: '12 CG Road, Ahmedabad',
          pickup_latitude: '23.030000',
          pickup_longitude: '72.570000',
          drop_address: 'Navrangpura, Ahmedabad',
          drop_latitude: '23.036000',
          drop_longitude: '72.561000',
        },
      ]),
    };
    const service = new OrdersService(
      { transaction: async (work: (db: object) => Promise<unknown>) => work({}) } as never,
      orders as never,
      {
        findRiderProfileIdByIdentity: jest.fn(async () => CANONICAL),
        findRider: jest.fn(async () => ({
          rider_profile_id: CANONICAL,
          approval_status: 'APPROVED',
          online_status: 'OFFLINE',
          deactivated_at: null,
        })),
      } as never,
      {} as never,
      {} as never,
      {} as never,
      { find: jest.fn(), insert: jest.fn() } as never,
      new OrderStateMachine(),
      { getOrThrow: jest.fn(() => ({ offerTtlSeconds: 300 })) } as never,
      { assertNotSuspended: jest.fn() } as never,
      { onNewOffer: jest.fn(), onOffersUnavailable: jest.fn(), onStatusChange: jest.fn() } as never,
      {} as never,
      { captureOnDelivered: jest.fn() } as never,
      {} as never,
    );

    const body = await service.listRiderOffers({
      identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      role: 'RIDER',
      profileId: SESSION,
    });

    expect(orders.listOffersForRider).toHaveBeenCalledWith(CANONICAL);
    expect(body.offers).toHaveLength(1);
    const offer = body.offers[0];
    expect(offer.trip_fare).toBe('500.00');
    expect(offer.rider_amount).toBe('425.00');
    expect(offer.trip_fare).not.toBe(offer.rider_amount);
    expect(offer.pickup_address).toBe('12 CG Road, Ahmedabad');
    expect(offer.drop_address).toBe('Navrangpura, Ahmedabad');
    expect(offer.distance_km).toBe('1.300');
    expect(offer.vehicle_category_name).toBe('Bike');
    expect(offer.package_weight_kg).toBe('2.000');
    expect(offer.estimated_duration_seconds).toBe(plannedTripDurationSeconds(1.3));
    expect(offer.expires_at).toBe(new Date(createdAt.getTime() + 300_000).toISOString());
    expect(offer.offer_ttl_seconds).toBe(300);
  });
});
