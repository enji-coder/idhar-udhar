import { ErrorCodes } from '../common/errors/error-codes';
import { OrderStateMachine } from './order-state-machine';
import { OrdersService } from './orders.service';

const ORDER = '55555555-5555-4555-8555-555555555555';
const CUSTOMER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const RIDER = '22222222-2222-4222-8222-222222222222';

describe('OrdersService.getAssignedRiderLocation', () => {
  function build(status: string, riderProfileId: string | null) {
    const order = {
      order_id: ORDER,
      customer_profile_id: CUSTOMER,
      rider_profile_id: riderProfileId,
      canonical_status: status,
    };
    const orders = {
      findById: jest.fn(async () => order),
    };
    const locations = {
      getRiderLocationForConsumer: jest.fn(async () => ({
        store: 'memory',
        durable: false,
        location: {
          latitude: 23.02,
          longitude: 72.57,
          accuracy_meters: 8,
          heading: null,
          speed: null,
          recorded_at: '2026-10-03T00:00:00.000Z',
          received_at: '2026-10-03T00:00:00.000Z',
        },
        stale: false,
      })),
    };
    const service = new OrdersService(
      {} as never,
      orders as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      new OrderStateMachine(),
      { getOrThrow: jest.fn() } as never,
      {} as never,
      {} as never,
      {} as never,
      { captureOnDelivered: jest.fn() } as never,
      locations as never,
    );
    return { service, locations };
  }

  it('returns the assigned rider fix for the owning customer', async () => {
    const { service, locations } = build('EN_ROUTE_PICKUP', RIDER);
    const body = await service.getAssignedRiderLocation(
      { role: 'CUSTOMER', profileId: CUSTOMER, identityId: 'i1' } as never,
      ORDER,
    );
    expect(body.rider_profile_id).toBe(RIDER);
    expect(locations.getRiderLocationForConsumer).toHaveBeenCalledWith(RIDER);
    expect(body.location?.latitude).toBe(23.02);
  });

  it('rejects when no rider is assigned', async () => {
    const { service } = build('SEARCHING', null);
    await expect(
      service.getAssignedRiderLocation(
        { role: 'CUSTOMER', profileId: CUSTOMER, identityId: 'i1' } as never,
        ORDER,
      ),
    ).rejects.toMatchObject({ code: ErrorCodes.ORDER_NOT_MODIFIABLE });
  });
});
